/* vim: set ts=4 tw=4: */
/*
 * Version: MPL 1.1 / GPLv3+ / LGPLv3+
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Initial Developer of the Original Code is
 *       Fabian Deutsch <fabian.deutsch@gmx.de>
 * Portions created by the Initial Developer are Copyright (C) 2010 the
 * Initial Developer. All Rights Reserved.
 *
 * Contributor(s): 
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 3 or later (the "GPLv3+"), or
 * the GNU Lesser General Public License Version 3 or later (the "LGPLv3+"),
 * in which case the provisions of the GPLv3+ or the LGPLv3+ are applicable
 * instead of those above.
 */


using GeneticProgramming;
using VirtualMachine;

namespace LinearGeneticProgramming
{

	public delegate bool TerminationFunc();
	public delegate void ObjectivesFunc( Individual i );
	


	/*
	 * Algorithm 2.1 (LGP algorithm)
	 */
	public class LgpSubPopulation : Object
	{
		public LgpSettings settings;
		
		IndividualSettings individual_creation_settings;
		public Individual[] individuals;
		
	
		int _generation;
		public int generation {
			get { return _generation; }
		}
		
		public ObjectivesFunc objectivesDelegate;
		
		public TerminationFunc terminationDelegate;
		
		/*
		 * Selection related
		 */
		TournamentResult[] results;
		
		Individual[] immigrants;		

		Individual[] _front;
		public Individual[] front { 
			get { return _front; }
			set { _front = value; }
		}
		
		public Individual[] vips;
		
		

		public LgpSubPopulation( LgpSettings s, IndividualSettings inds)
		{
			base();
			
			this.settings = s;
			
			this.individual_creation_settings = inds;
			
			/*Individual powi = new Individual.with_program(
					this.individual_creation_settings,
					new Program.try_parse ("r0 = ^ r1 r7\nr0 = ^ r1 r7")
				);*/
			//debug("Powi: %s", powi.to_string());
			//this.vips.append (powi);
		}
		
		public void initialize()
		{
			// 1
			this.individuals = new Individual[ settings.PopulationSize / settings.NumberOfDemes ];
			for( int i = 0 ; i < individuals.length ; i++ )
			{
				individuals[i] = IndividualFactory.make_from_type( InitilizationType.EFF, ref this.individual_creation_settings );
				assert( individuals[i] != null );
			}
		}

		public void evolve()
		{
				this.evaluate();
				this.select();
				this.reproduce();
//				this.evaluate();
				this.variate();
				this.evaluate();
//drc("end", this.individuals);
		}

		/**
		 * Evaluates each individual, that means: We expect 
		 * Individual.objectives to be filled.
		 * @return	Number of evaluations.
		 */
		public int evaluate(bool force = false)
		{
			int ne = 0;
			
			foreach( unowned Individual ind in this.individuals )
			{
				if( evalind(ind, force) ) ne++;
			}
			
			foreach( unowned Individual ind in this.immigrants )
			{
				if( evalind(ind, force) ) ne++;
			}
			
//			debug("evaluated %d", ne);
			return ne;
		}
		bool evalind( Individual ind, bool force )
		{
			if (force) ind.objectives = null;
			if( ind.has_changed )
			{
				objectivesDelegate( ind );
				assert( ind.objectives.length > 0 );
//				debug("eval of %d", ind.id);
				return true;
			}
			return false;
		}

		public void select()
		{
			/* Shuffle the population */
			Posix.qsort( this.individuals, this.individuals.length, sizeof(Individual), (a,b) => {
				return  Random.boolean() ? -1 : 1;
			});
			
			this.results = new TournamentResult[ this.settings.TournamentSize ];
			
			switch( this.settings.SelectionType )
			{
				case SelectionType.NONE:
					break;
					
				case SelectionType.LGP_MATING:
					classic_select();
					break;
					
				case SelectionType.NSGA2_DEB:
				default:
					nsga2_deb_select();
					break;
			}
		}
		
		void nsga2_deb_select()
		{
			if( this.immigrants == null )
			{
				this.immigrants = new Individual[0];
			}
			
			GeneticProgramming.MOEA.NSGA2.nsga2_select( ref this.individuals, this.immigrants, ref this.results );
		}
		
		void classic_select()
		{

			this.replace_worst_individuals_with( this.immigrants );

			evaluate();
			
			foreach(unowned TournamentResult r in this.results)
			{
				unowned Individual parent = r.winner;
				
				// 6
				if( front == null || front.length == 0 || parent.objectives[0] < front[0].objectives[0] )
				{
					// 7
					front = new Individual[]{ parent.clone() };
				}
			}

//			float sweight = 0.0001025f;
			
//			this.parents = new Individual[2];
//			this.underdog_replacement = new Individual[ this.individuals.length ];
			this.results = new TournamentResult[2];
			
			List<Individual> participants = new List<Individual>();
			foreach(unowned Individual i in this.individuals) participants.append(i);
			
			for( int i = 0 ; i < results.length ; i++ )
			{
				TournamentResult r = TournamentResult();
				
				for( int j = 0 ; j < settings.TournamentSize; j++ )
				{
					// 2
					int i1id = rint((int)participants.length());
					unowned Individual i1 = participants.nth_data( i1id );
					participants.remove( i1 );

					// 3
					//if( winner == null ||  ( i1.objectives[0] * sweight * i1.objectives[1] ) < ( winner.objectives[0] * sweight * winner.objectives[1] ) )
					if( r.winner == null ||  i1.selection_objectives[0] < r.winner.selection_objectives[0] )
					{
						if(r.winner != null)
						{
//							this.underdog_replacement[ wid ] = i1;
							r.looser = r.winner;
						}
						r.winner = i1;
//						wid = i1id;
					}
					else
					{
						//this.underdog_replacement[ i1id ] = winner;
						r.looser = i1;
					}
				}
//				parents[ i ] = winner;
				results += r;
			}

			// 4 ...
			

			// sortieren f"ur sp"ateres migrieren			
			Posix.qsort( this.individuals, this.individuals.length, sizeof(Individual), (vap,vbp) => {
				unowned Individual ap = (Individual*) vap;
				unowned Individual bp = (Individual*) vbp;
				assert( !(ap.selection_objectives[0].is_nan() || bp.selection_objectives[0].is_nan()) );
				bool ap_lte_bp = ( ap.selection_objectives[0] - bp.selection_objectives[0] ) <= 0;
				return  ap_lte_bp ? -1 : 1;
			});
			
			assert( individuals[0].selection_objectives[0] <= individuals[1].selection_objectives[0]);
		}

		public void reproduce()
		{

			for( int i = 0 ; i < this.results.length ; i++ )
			{
				unowned TournamentResult cur = this.results[i];
				
				assert( cur.winner != null );
				assert( cur.looser != null );
				
				bool is_parent = false;
				foreach (unowned TournamentResult r in this.results)
				{
					unowned Individual p = r.winner;
					if (cur != r && cur.looser == p)
					{
						is_parent = true;
					}
				}
				if (is_parent)
				{
					// wir wollen nicht das ein looser parent ist, da er sp"ater "uberschrieben wird
					continue;
				}
				
				Individual clone = cur.winner.clone();
				for( int k = 0 ; k < this.individuals.length ; k++ )
				{
					if( this.individuals[k] == cur.looser )
					{
						this.individuals[k] = clone;
					}
				}
			}
		}
		

		/*
		 * Variates the parents in place.
		 */
		public void variate()
		{

			// HACK!!!!
			assert( this.results.length % 2 == 0 );
			int i = 0;

			for (i = 0; i < this.results.length ; i+=2)
			{
				assert( results[i].winner != null );
				assert( index_of_individual(results[i].winner) != -1 );
				assert( results[i+1].winner != null );
				assert( index_of_individual(results[i+1].winner) != -1 );
			
				// 5
				if( Random.next_double() < settings.CrossoverProbability )
				{
					if (this.vips != null && this.vips.length > 0 && Random.boolean ()) // FIXME hier praobability!!!!!!!!!!!!
					{
						debug("vip corssing");
						//results[i].winner.crossoverWith( pick_clone_from_forced() );
						results[i].winner.crossoverWith (vips[Random.int_range(0,(int)vips.length)].clone());
						//debug("w1 %s", results[i].winner.to_string());
						//results[i+1].winner.crossoverWith( pick_clone_from_forced() );
						results[i+1].winner.crossoverWith (vips[Random.int_range(0,(int)vips.length)].clone());
						//debug("w2 %s", results[i+1].winner.to_string());
					}
					else
					{
						results[i].winner.crossoverWith( results[i+1].winner );
					}
				}
			
				if( Random.next_double() < settings.MutationProbability )
				{
					results[i].winner.mutate();
					results[i+1].winner.mutate();
				}
			}
		}
		
		


		public void immigrate( Individual[] migrants )
		{
			this.immigrants = migrants;
			foreach (unowned Individual i in this.immigrants)
			{
				i.objectives = null;
				i.selection_objectives = null;
			}
		}

		/**
		 * Emmigrates the best to dst
		 * IMPORTANT: expects individuals to be sorted 
		 */
		public Individual[] emigrate(int count)
		{
			Individual[] emigrants = new Individual[ count ];
			for( int i = 0 ; i < count ; i++ )
			{
				emigrants[ i ] = individuals[ i ].clone();
//				debug("emigrant %d with clone %d", individuals[ i ].id, emigrants[i].id);
			}
			return emigrants;
		}

		/**
		 * Replaces the worst
		 * IMPORTANT: expects individuals to be sorted 
		 */
		void replace_worst_individuals_with( Individual[] rs )
		{
			int offset = individuals.length - rs.length;
			for(int i = 0 ; i < rs.length ; i++ )
			{
				individuals[ offset + i ] = rs[i];
			}
		}


		inline int index_of_individual(Individual? ind)
			requires( ind != null )
		{
			for( int i = 0 ; i < individuals.length ; i++)
				if( individuals[i] == ind ) return i;
			return -1;
		}


		public LgpStatistics getStatistics()
		{
			LgpStatistics stats = LgpStatistics() {
				desc = this.generation.to_string(),
				num_individuals = individuals.length
			};
			
			
			ObjectiveStatistics[] os = new ObjectiveStatistics[ this.individuals[0].objectives.length ];
			
			for( int i = 0 ; i < os.length ; i++ )
			{
				os[i] = ObjectiveStatistics() {
					desc = i.to_string(),
					min = double.MAX,
					avg = 0,
					max = double.MIN
				};
				
				foreach(unowned Individual ind in this.individuals)
				{
					if( ind.objectives[i] < os[i].min ) os[i].min = ind.objectives[i];
					if( ind.objectives[i] > os[i].max ) os[i].max = ind.objectives[i];
					os[i].avg += ind.objectives[i] / this.individuals.length;
				}
			}
			
			stats.objectiveStatistics = os;

			return stats;
		}
	}
}


/*void drc(string p, Individual[] inds, int r = -1)
{
	
	debug("START %s (#%d)", p, inds.length);
	StringBuilder sb = new StringBuilder();
	if( r > -1 )
	{
		sb.append( inds[r].refcinfo() );
	}
	else
	{
		foreach(unowned Individual i in inds)
		{
//			sb.append( "\n" + i.refcinfo() );
			if(i.objectives == null)
				sb.append( "- no obs -" );
			else
				sb.append_printf( "%d %s\n", i.id, i.objectives.to_string());
		}
	}
	debug(sb.str);
	debug("END %s", p);
}*/
