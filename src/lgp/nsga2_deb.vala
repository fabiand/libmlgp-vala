/* vim: set ts=4 tw=4: */

using Gee;
using Logging;

namespace GeneticProgramming.MOEA.NSGA2
{

//	Logger logger;
		
	inline void write_to_file(string filename, string contents)
	{
		File f = File.new_for_path( filename );
		try {
			f.replace_contents( contents, contents.length, "", false, 0, null, null );
		} catch(Error e) {
			debug(@"Writing contents to '$filename'.");
			error(e.message);
		}
	}


	inline int crowded_comparison_operator(Individual a, Individual b)
	{
		bool a_is_less = (a.rank < b.rank) || ((a.rank == b.rank) && (a.distance > b.distance));
		return a_is_less ? -1 : 1;
	}

	// gnomeSort
	inline void gnomesort_by_objective(ref Individual[] a, int oid)
	{
		int pos = 0;
		while( pos < a.length )
		{
			if( (pos==0) || (a[pos].objectives[oid] >= a[pos-1].objectives[oid]) )
			{
				pos++;
			}
			else
			{
				// swap
				unowned Individual frst = a[pos];
				a[pos] = a[pos-1];
				a[pos-1] = frst;
				pos--;
			}
		}
	}



	/**
	 * DOmination appears if this is at least as good as b in all objectives, and in one better.
	 */
	inline bool dominates(Individual a, Individual b)
	{
		bool a_better = false,
		     b_better = false;

		for (int i = 0; i < a.selection_objectives.length ; i++)
		{
			if( a.selection_objectives[i] < b.selection_objectives[i] )
			{
				a_better = true;
			}
			else if( a.selection_objectives[i] > b.selection_objectives[i] )
			{
				b_better = true;
			}
		}
		
		if (a_better && !b_better)
			return true;
		else if (!a_better && b_better)
			return false;
		else
			return false;
	}

	public string individual_to_csv(Individual individual, string? filename = null)
	{
		StringBuilder sb = new StringBuilder();
		for( int o = 0 ; o < individual.selection_objectives.length ; o++ ) sb.append_printf("\t%.4f", individual.selection_objectives[o]);
		if( filename != null ) write_to_file( filename, sb.str );
		return sb.str;
	}

	class Population : Object
	{
		Individual[] individuals;
	
		public Population()
		{
			base();
			
			this.individuals = new Individual[0];
		}
	
		public Population.with_individuals(Individual[] inds)
		{
			base();
			
			this.individuals = inds;
		}
	
		public new Individual get(int idx)
		{
			return this.individuals == null || idx >= this.individuals.length ?
				null :
				this.individuals[idx];
		}
	
		public new void set(int idx, Individual i)
		{
			if(this.individuals != null || idx < this.individuals.length)
			{
				this.individuals[idx] = i;
			}
		}
		
		public Population slice(long start, long end)
		{
			return new Population.with_individuals( this.individuals[ start : end ] );
		}
	
		public int size()
		{
			return this.individuals.length;
		}
	
		public bool contains(Individual i)
		{
			// FIXME naive
			bool exists = false;
			foreach(unowned Individual n in this.individuals)
			{
				if( n == i )
				{
					exists = true;
					break;
				}
			}
			return exists;
		}
	
		public inline void append(Individual i)
		{
			this.individuals += i;
		}
	
		public void sort_by_objective(int oid)
		{
			gnomesort_by_objective(ref this.individuals, oid);
		}
	
		public void sort_by_crowding_distance()
		{
			Posix.qsort(this.individuals, this.individuals.length, sizeof(Individual), (vap,vbp) => {
				Individual* ap = *((Individual**)vap);
				Individual* bp = *((Individual**)vbp);
				return crowded_comparison_operator( ap, bp );
			});
		}
	
		public static Population merge(Population a, Population b)
		{
			Population c = new Population();
			c.individuals = new Individual[ a.size() + b.size() ];
//logger.debug(" new pop size %d, %d".printf( a.size(), c.size()));
			for( int i = 0 ; i < c.size() ; i++ )
			{
				if( i < a.size() )
				{
					c.individuals[i] = a[ i ];
				}
				else
				{
					c.individuals[i] = b[ i - a.size() ];
				}
			} 
			return c;
		}
	
		public unowned Individual[] get_individuals()
		{
			return this.individuals;
		}
	
		public string to_string()
		{
			StringBuilder sb = new StringBuilder();
			sb.append("Population:\n");
			foreach( unowned Individual i in this.individuals ) sb.append_printf("\t%s\n", i.to_string());
			return sb.str;
		}
	
		public string to_csv(string? filename = null)
		{
			StringBuilder sb = new StringBuilder();
			foreach( unowned Individual i in this.individuals ) sb.append_printf("%s\n", individual_to_csv(i));
			if( filename != null ) write_to_file( filename, sb.str );
			return sb.str;
		}
	
		public Iterator iterator()
		{
			return new Iterator(this);
		}
	
		public class Iterator
		{
			Population pop;
			int idx;
		
			public Iterator(Population p)
			{
				this.pop = p;
				this.idx = 0;
			}
			public Individual? next_value()
			{
				return this.idx < this.pop.size() ?
					this.pop[this.idx++] :
					null;
			}
		}
	}

	class Fronts
	{
		Population[] front;
	
		public int length {
			get { return this.front.length; }
		}
	
		public Fronts()
		{
			this.front = new Population[0];
		}
	
		public new unowned Population get(int idx)
		{
			return this.front[idx];
		}

		public new void set(int idx, Population val)
		{
			this.front[idx] = val;
		}

		public Individual[] get_individuals()
		{
			Individual[] fis = new Individual[0];
			foreach(unowned Population p in this.front )
			{
				foreach( unowned Individual i in p.get_individuals() )
				{
					fis += i;
				}
			}
			return fis;
		}
	
		public void append(Population p)
		{
			this.front += p;
		}
	
		public string to_string()
		{
			StringBuilder sb = new StringBuilder();
			sb.append("Fronts:\n");
			for( int i = 0 ; i < this.front.length ; i++ )
			{
				unowned Population p = this.front[i];
				sb.append_printf("Rank %d, %s",  i, p.to_string() );
			}
			return sb.str;
		}
	}

	Fronts fast_nondominated_sort(Population P)
//	ensures( P.size() == result.get_individuals().length )
	{
		int ic = 0, pc = 0;
		
		Fronts F = new Fronts();
		//{
			F.append( new Population() );
		
			Map<Individual,Population> S = new HashMap<Individual,Population>();
			Map<Individual,int> n = new HashMap<Individual,int>();
			
			{
				Individual[] _inds = new Individual[0];
//				logger.debug("initdup check");
				foreach(Individual io in P)
				{
//					logger.debug("check %d".printf(io.id));
					_inds += io;
				}
				check_dups(_inds);
			}
			
			foreach( Individual p in P )
			{
				pc++;
				S.set(p, new Population());
				n.set(p, 0);
		
				foreach( Individual q in P )
				{
					if( dominates(p, q) )
					{
						S.get(p).append(q);
						ic++;
					} 
					else if( dominates(q, p) )
					{
						n.set(p, n.get(p)+1);
					}
				}
		
				if( n.get(p) == 0 )
				{
					p.rank = 1;
					F[0].append(p);
				}
			}
			
			{
				Individual[] _inds = new Individual[0];
				foreach(Individual io in P)
				{
//					logger.debug("setting %d domcount to %d".printf( io.id, n.get(io)));
					_inds += io;
				}
				check_dups(_inds);
			}
			
//			logger.debug("nondomsort handeld %d inds, #P:%d, #S:%d, #n:%d".printf( pc, P.size(), S.size, n.size));
			int i = 1;
	
			while( F.length == i )
			{
				Population Q = new Population();
				foreach( Individual p in F[i-1] )
				{
					Population dominated_by_p = S.get(p);
					foreach( Individual q in dominated_by_p )
					{
						n.set(q, n.get(q)-1);
						if( n.get(q) == 0 )
						{
							q.rank = i + 1;
							Q.append(q);
							ic++;
						}
					}
				}
				i++;
				if( Q.size() > 0 )
				{
					F.append( Q );
				}
			}
		//}
		
		foreach(Individual io in P)
		{
//			logger.debug("setting %d arnk is %d".printf( io.id, io.rank));
		}
		
//		logger.debug("nondomsort ic %d, Flen %d".printf( ic, F.length));
		int sui = 0;
		for( int fi = 0 ; fi < F.length ; fi++)
		{
//			logger.debug("   %d: %d".printf( fi, F[fi].size()));
			sui += F[fi].size();
		}
//		logger.debug("sui: %d".printf(sui));
		
		return F;
	}

	void crowding_distance_assignment(Population I)
	{
		if( I.size() <= 2 )
		{
			foreach(Individual i in I)
			{
				i.distance = float.MAX;
			}
			return;
		}
	
		int l = I.size();
	
		foreach( Individual i in I )
		{
			i.distance = 0;
		}
		for( int m = 0 ; m < I[0].selection_objectives.length ; m++ )
		{
			I.sort_by_objective(m);
			
			float omin = I[0].selection_objectives[m],
			      omax = I[l-1].selection_objectives[m];
			
			I[0].distance = float.MAX;
			I[l-1].distance = float.MAX;
			
			for( int i = 1 ; i < (l-1) ; i++ )
			{
				Individual ind = I[i]; // OK!
				ind.distance += ( I[i+1].selection_objectives[m] - I[i-1].selection_objectives[m] ) / (omax - omin); // OK!
//				I[i].distance += ( I[i+1].selection_objectives[m] - I[i-1].selection_objectives[m] ) / (omax - omin); // BUGGY!
				// FIXME BUG I[i].distance geht nicht!!!!
			}
		}
	}

	void binary_tournament_selection(ref Individual[] pop, ref TournamentResult[] results)
//	requires( underdog_replacement.length == pop.length )
//	requires( underdog_replacement[0] == null )
	{
//		foreach( unowned Individual ind in parents ) assert( ind == null );
//		foreach( unowned Individual ind in underdog_replacement ) assert( ind == null );
		
		int i = 0;
		
		for( i = 0 ; i < results.length ; )
		{
//			logger.debug("Tournament ...");
			
			int a = Random.int_range(0, pop.length),
			    b = Random.int_range(0, pop.length);
			
//			logger.debug("%d vs %d, from %d".printf(a, b, pop.length));
			if( a == b )
			{
				continue;
			}
			
			int winner = crowded_comparison_operator(pop[a], pop[b]) < 0 ? a : b,
			    looser = b;
			
			if( winner == b )
			{
				looser = a;
			}

			bool looser_is_parent = false, looser_lost_already = false;
			foreach(unowned TournamentResult r in results)
			{
				if( pop[looser] == r.winner )
				{
					looser_is_parent = true;
				}
				if( pop[looser] == r.looser )
				{
					looser_lost_already = true;
				}
			}
			if( looser_is_parent || looser_lost_already )
			{
				// wir wollen keine verliere die bereiets winner sind. denn dann gibst probleme :)
				continue;
			}
			
//logger.debug("Selecting %3d as parent, replacing %3d".printf( 
//			pop[winner].id, 
//			pop[looser].id
//			));

//			underdog_replacement[ looser ] = pop[ winner ];
//			parents[ i ] = pop[ winner ];
			TournamentResult r = TournamentResult();
			
			r.winner = pop[winner];
			r.looser = pop[looser];
			
			results[i] = r;
			
			i++;
		}
		
//		logger.debug("nsga2 selected %d".printf( i));
	}


	Population nsga2(Population P, Population Q)
	{
		Population R,
			       P2;
		Fronts F;
	
		R = Population.merge( P, Q );
		assert (R.size() == P.size() + Q.size());
//logger.debug(" Rlen %d (%d+%d)".printf( R.size(), P.size(), Q.size()));
		F = fast_nondominated_sort(R);
//logger.debug("Flen %d, num inds %d".printf(F.length, F.get_individuals().length));
		P2 = new Population();
		
//		for( int i = 0 ; i < F.length ; i++ )
		int fi = 0;
		while( P2.size() < P.size() )
		{
			crowding_distance_assignment( F[fi] );
			P2 = Population.merge( P2, F[fi] );
			fi++;
		}
		
		F = null;
		
		P2.sort_by_crowding_distance();
//logger.debug("P2 len %d".printf(P2.size()));

		P2 = P2[ 0 : P.size() ];

//logger.debug("P2 len FINAL %d".printf(P2.size()));
		return P2;
	}


	public void nsga2_select( ref Individual[] pop, Individual[] offsprings, ref TournamentResult[] results)
	{
//		logger = new Logger();
//		logger.add_handler( new PrintLogHandler() );
		
//		logger.path = "nsga2";
		
		{
//			logger.debug("Starting NSGA2 select.");
			Population P = new Population.with_individuals( pop );
		
			Population Q = nsga2( P, new Population.with_individuals(offsprings));
				
			Individual[] sorted_pop = Q.get_individuals();
			pop = sorted_pop;
		}
		
		binary_tournament_selection( ref pop, ref results );
		
//		debug("No of individuals after select: %d", pop.length);
	}
	





void check_dups(Individual[] inds)
{
	return;
	Set<Individual> insts = new HashSet<Individual>();
	Set<int> ids = new HashSet<int>();
	
	foreach( unowned Individual ind in inds )
	{
		//debug("dupc : %d", ind.id);
		if( ind == null )
		{
			debug("ins is null");
			assert(false);
		}
		if( insts.contains(ind) )
		{
			debug("instance alread there: %d", ind.id);
			assert(false);
		}
		if( ids.contains(ind.id) )
		{
			debug("id alread there: %d", ind.id);
			assert(false);
		}
		insts.add(ind);
		ids.add(ind.id);
	}

}
}




