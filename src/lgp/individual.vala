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


using VirtualMachine;


public int _individual_count = 0;
public int _individual_no = 0;

namespace GeneticProgramming
{
	public class Individual : Object
	{
		public int rank { get; set; }
		public double distance { get; set; }
		
		public Objectives selection_objectives { get; set; }
		public Objectives objectives { get; set; }
		
		public Program program;

		int _id;
		public int id {
			get { return this._id; }
		}

		/**
		 * Is used to decide about a re-evaluation.
		 */
		public bool has_changed {
			get { return this.selection_objectives == null; }
		}
		
		public signal void on_change ();
		public signal void on_destroy ();

		protected unowned IndividualSettings creation_info;

		public Individual()
		{
			base();
			
			_individual_count++;
			
			this._id = _individual_no++;
			
			this.objectives = null;
			this.selection_objectives = null;
			//debug("pop: an individual!");
			this.on_change.connect( () => {
				this.objectives = null;
				this.selection_objectives = null;
			});
		}
		
		~Individual()
		{
			_individual_count--;
			this.on_destroy();
		}

/*		public Individual.with_objectives(Objectives o)
		{
			this();
			
			this.objectives = o;
		}*/

		public Individual.from_random( IndividualSettings c )
		{
			this();
			
			this.creation_info = c;
			this.program = VirtualMachine.create_random_program( 
				c.min_length, c.max_initial_length, 
				c.used_ops, 
				c.no_of_vars, 
				c.no_of_calcs, 
				c.no_of_consts
			);
			
			check();
		}

		public Individual.completely_effective( IndividualSettings c )
		{
			this();
			
			this.creation_info = c;
			this.program = VirtualMachine.create_effective_program( 
				c.min_length, c.max_initial_length, 
				c.used_ops, 
				c.no_of_vars, 
				c.no_of_calcs, 
				c.no_of_consts
			);
			
			check();
		}
		
		public Individual.with_program( IndividualSettings c, Program iset )
		{
			this();
			
			this.creation_info = c;
			this.program = iset;
			this.program.used_ops = c.used_ops;
			this.program.no_of_vars = c.no_of_vars;
			this.program.no_of_calcs = c.no_of_calcs;
			this.program.no_of_consts = c.no_of_consts;
			
			validate ();
		}

		public string to_string(string[]? alias = null)
		{
			return VirtualMachine.dump( this.program, alias );
		}

		public string to_function(string[]? alias = null)
		{
			return VirtualMachine.flatten( this.program, 0, alias );
		}
		
		public string objectives_to_string()
		{
			StringBuilder sb = new StringBuilder();
			foreach(float f in this.objectives)
			{
				sb.append_printf("%.4f\t", f);
			}
			return sb.str;
		}

		public int size()
		{
			return this.program.length;
		}
		
		public Individual clone()
		{
			Individual ind = new Individual();
			ind.program = this.program.clone();
			ind.creation_info = this.creation_info;
			ind.objectives = null;
			ind.selection_objectives = null;
			return ind;
		}

		public void mutate ()
		{
			MutationType mType = MutationType.MUT;
			switch( mType )
			{
				case MutationType._SIMPLE: 
					this.simpleMutate(); 
					break;
					
				case MutationType.MUT: 
					this.instruction_mutation();
					this.micro_mutation();
					break;
					
				default: 
					critical("Mutation type not yet implemented."); 
					break;
			}
			
			this.on_change();
		}

		public void crossoverWith (Individual neighbor)
		{
			CrossoverType xType = CrossoverType.EFFCROSS;
			try 
			{
				switch( xType )
				{
					case CrossoverType._ONEPOINT: 
						this.onePointCrossoverWith( neighbor ); 
						break;
					
					case CrossoverType._TWOPOINT: 
						this.twoPointCrossoverWith( neighbor ); 
						break;
					
					case CrossoverType.CROSS: 
						this.linear_crossover( neighbor );
						break;
					
					case CrossoverType.EFFCROSS: 
						this.linear_crossover( neighbor );
						foreach( unowned Individual i in new Individual[] { this, neighbor } )
						{
							i.program.makeEffective();
							if( i.size() == 0 )
							{
/*								this.program.instructions = new Instruction[1];
								this.program[0] = create_random_instruction( creation_info.used_ops, creation_info.no_of_vars, creation_info.no_of_calcs, creation_info.no_of_consts );
								this.program[0].dst = 0;*/
								Individual ctr = new Individual.completely_effective( i.creation_info );
								i.program.instructions = ctr.program.instructions;
							}
						}
						break;
				
					default: 
						critical("Crossover type not yet implemented."); 
						break;
				}
			}
			catch(Error e)
			{
				critical(e.message);
			}
			
			this.on_change();
		}
		

		/*
		 * Algorithm 5.1 (linear crossover)
		 */
		void linear_crossover(Individual neighbor)
		{
			unowned Individual gp1 = this,
			           gp2 = neighbor;
			
			int i1, i2, /* Crossover Points */
			    /* d,  Distance of Crossover Points / |i1-i2| */
			    dmax,
			    /* sd,  Difference in Segment Length / |sl1-sl2| */
			    sdmax,
			    lmin = creation_info.min_length, 
			    lmax = creation_info.max_length, /* Min-/Maximum program length */
			    slmax, /* Maximum Segment Length */
			    sl1, sl2; 

			// 1   
			if( this.size() > neighbor.size() )
			{
				gp1 = neighbor;
				gp2 = this;
			}

			dmax = gp1.size() - 1;
			sdmax = dmax;
			
			slmax = 5;

			if( gp1.size() < 2 ) 
			{
				debug ("Neighbor to short!");
				return;
			}

			i1 = rint( gp1.size() - 1 );
			
			int i2_min = int.min(i1 - dmax, gp1.size()-1).clamp(0, gp1.size()),
			    i2_max = 1 + int.min(i1 + dmax, gp1.size()-1).clamp(0, gp1.size());
			assert( i2_min < i2_max );
			assert( i2_min >=0 );
			i2 = Random.int_range( i2_min, i2_max );
//debug("%d %d %d %d", i2_min, i2_max, i2, i1);
			assert( (i1 - i2).abs() <= int.min(gp1.size() - 1, dmax).clamp(0, gp1.size()) );
			assert( gp1.size() <= gp2.size() );

			// 2
//debug("%d d", int.min(slmax, gp1.size()-i1));
			sl1 = 1 + rint(int.min(slmax, gp1.size()-i1));
			assert( 1 <= sl1 );
			assert( sl1 <= int.min(gp1.size()-i1, slmax) );

			sl2 = 1 + rint(int.min(slmax, gp2.size()-i2));
			assert( 1 <= sl2 );
			assert( sl2 <= int.min(gp2.size()-i2, slmax) );
			
			int num_sdmax_trials = 15;
			while( (sl1 - sl2).abs() > sdmax )
			{
				sl2 = 1 + Random.int_range ( 0, int.min(slmax, gp2.size()-i2) );
				
//				if( (sl1 - sl2).abs() <= sdmax && sl1 <= sl2 ) break;
				if( num_sdmax_trials == 0 ) 
				{
					sl2 = sl1;
					break;
				}
				num_sdmax_trials--;
			}

			// 4
			sl1 = 1 + (sl1-1) % sl2;
			assert( sl1 <= sl2 );

			// 5
			if( (gp2.size() - (sl2-sl1)) < lmin || (gp1.size() + (sl2-sl1)) > lmax )
			{
				// a
				if( Random.boolean() )
				{
					sl2 = sl1;
				}
				else
				{
					sl1 = sl2;
				}
				// b
				if( i1 + sl1 > gp1.size() )
				{
					sl1 = sl2 = gp1.size() - i1;
				}
			}
			
			
			Instruction[] gp1_new_instructions = new Instruction[ gp1.size() - sl1 + sl2 ];
			int i = 0;
			for( int j = 0 ; j < i1 ; )
				gp1_new_instructions[ i++ ] = gp1.program[ j++ ];
			for( int j = i2 ; j < i2 + sl2 ; )
				gp1_new_instructions[ i++ ] = gp2.program[ j++ ];
			for( int j = i1 + sl1 ; j < gp1.size() ; )
				gp1_new_instructions[ i++ ] = gp1.program[ j++ ];


			Instruction[] gp2_new_instructions = new Instruction[ gp2.size() - sl2 + sl1 ];
			i = 0;
			for( int j = 0 ; j < i2 ; )
				gp2_new_instructions[ i++ ] = gp2.program[ j++ ];
			for( int j = i1 ; j < i1 + sl1 ; )
				gp2_new_instructions[ i++ ] = gp1.program[ j++ ];
			for( int j = i2 + sl2 ; j < gp2.size() ; )
				gp2_new_instructions[ i++ ] = gp2.program[ j++ ];

			gp1.program.instructions = gp1_new_instructions;
			gp2.program.instructions = gp2_new_instructions;
		}


		/*
		 * 5.3 one-segment recombination
		 */
		/*void one_segment_recombination()
		{
			int TYPE_INSERTION = 0,
			    TYPE_DELETION = 1;
			
			double p_ins = 0.5,
			       p_del = 1 - p_ins;

			assert( p_ins + p_del == 1 );

			
		}*/

		/*
		 * Algorithm 6.1 (effective) instruction mutation
		 */
		void instruction_mutation()
		{
			bool effective_mutation = false;

			int TYPE_INSERTION = 0,
			    TYPE_DELETION = 1;
			
			double p_ins = 0.5,
			       p_del = 1 - p_ins;

			assert( p_ins + p_del == 1 );

			int mtype = Random.next_double() < p_ins ? TYPE_INSERTION : TYPE_DELETION;

			int l_max = this.creation_info.max_length,
			    l_min = this.creation_info.min_length;

			// 2
			int i = rint( this.program.length );

			// 3
			if( this.program.length < l_max 
			    && ( mtype == TYPE_INSERTION || this.program.length == l_min ) )
			{
				// 3.a
				IndividualSettings info = this.creation_info;
				this.program.insert_instruction( i, create_random_instruction( info.used_ops, info.no_of_vars, info.no_of_calcs, info.no_of_consts ) );
				
				if( effective_mutation )
				{
					// 3.b ...
				}
			}
			// 4
			else if( this.program.length > l_min
			         && ( mtype == TYPE_DELETION || this.program.length == l_max ) )
			{
				if( effective_mutation )
				{
					 // 4.a ...
				}
				
				// 4.b
				this.program.delete_instruction( i );
			}

			
			else
			{
//				critical("Macro: Should not be reached.");
			}
		}

		
		/*
		 * Algorithm 6.2 (effective) micro mutation
		 */
		void micro_mutation(bool effective_mutation = false)
		{
			if( this.program.length == 0 ) return;
			
			double p_regmut = 0.34,
			       p_opermut = 0.34,
			       p_constmut = 0.32,
			       p_const = 0.5;

			int d_const = 3;

			int TYPE_REGISTER = 0,
			    TYPE_OPERATOR = 1,
			    TYPE_CONSTANT = 2;
					
			assert( p_regmut + p_opermut + p_constmut ==  1 );

			// 1
			int i = rint( this.program.length );
			Instruction instruction = this.program[ i ];
			IndividualSettings info = this.creation_info;

			assert( instruction != null );
			
			// 2
			double rnd = Random.next_double();
			int mtype = ( rnd < p_regmut ) ?
				TYPE_REGISTER :
				( rnd < ( p_regmut + p_opermut ) ?
					TYPE_OPERATOR :
					TYPE_CONSTANT );

			// 3
			if( mtype == TYPE_REGISTER )
			{
				// 2.a
				if( Random.boolean() )
				{
					// 2.b destination
					if( effective_mutation )
					{
						// ...
					}
					else
					{
						instruction.dst = rint( info.no_of_vars + info.no_of_calcs );
					}
				}
				else
				{
					// 2.c operand (just the second)
					if( Random.next_double() < p_const )
					{
						instruction.r2 = info.no_of_vars + info.no_of_calcs + rint( info.no_of_consts );
					}
					else
					{
						instruction.r2 = rint( info.no_of_vars + info.no_of_calcs );
					}
				}
			}
			else if( mtype == TYPE_OPERATOR )
			{
				instruction.operation = info.used_ops[ rint( info.used_ops.length ) ];
			}
			else if( mtype == TYPE_CONSTANT )
			{
				instruction.r2 = info.no_of_vars + info.no_of_calcs + (rint( info.no_of_consts + d_const )%info.no_of_consts); // FIXME ist falsch
			}

			
			else
			{
//				critical("Micro: Should not be reached.");
			}
		}









		/*
		 * My naive ones ...
		 */
		void simpleMutate()
		{
			assert( this.program.used_ops.length > 1 );
			int ridx = rint(this.program.length);
			Instruction ins = this.program.instructions[ ridx ];

			int rmut = rint(4);
			switch( rmut )
			{
				case 0:
					/* Mutate dest */
					ins.dst = rint( this.program.no_of_vars + this.program.no_of_consts );
					break;

				case 1:
					/* Mutate op */
					int idx = rint( this.program.length );
					Operation rnd_op = this.program.used_ops[ rint(this.program.used_ops.length) ];
					this.program.instructions[ idx ].operation = rnd_op;
					break;

				case 2:
					/* Mutate r1 */
					ins.r1 = rint( this.program.no_of_vars + this.program.no_of_consts );
					break;

				case 3:
					/* Mutate r2 */
					ins.r2 = rint( this.program.no_of_vars + this.program.no_of_consts );
					break;

				default:
					assert ( false );
					break;
			}
		}

		void onePointCrossoverWith( Individual neighbor )
		{

			int max_idx = int.min( this.program.length, neighbor.program.length );
			int m_idx = rint( max_idx ),
			    n_idx = rint( max_idx );

			Instruction[] m_new_instructions = {};
			for( int i = 0 ; i < neighbor.program.length ; i++ )
			{
				m_new_instructions += i < m_idx ?
					this.program.instructions[ i ] :
					neighbor.program.instructions[ i ];
			}

			Instruction[] n_new_instructions = {};
			for( int i = 0 ; i < this.program.length ; i++ )
			{
				n_new_instructions += i < n_idx ?
					neighbor.program.instructions[ i ] :
					this.program.instructions[ i ];
			}

			this.program.instructions = m_new_instructions;
			neighbor.program.instructions = n_new_instructions;
		}

		void twoPointCrossoverWith( Individual neighbor ) throws LgpError
		{
//			assert( this != neighbor );

			Instruction[] m = this.program.instructions;
			Instruction[] n = neighbor.program.instructions;
			
			int m_selection_length = this.creation_info.min_length + rint(m.length - this.creation_info.min_length),
			    m_begin = rint(m.length - m_selection_length),
			    m_end = m_begin + m_selection_length,
			    m_remaining = m.length - m_selection_length;

			int n_selection_length = this.creation_info.min_length + rint(n.length - this.creation_info.min_length),
			    n_begin = rint(n.length - n_selection_length),
			    n_end = n_begin + n_selection_length,
			    n_remaining = n.length - n_selection_length;

			int m_new_length = m_remaining + n_selection_length,
			    n_new_length = n_remaining + m_selection_length;

			if( m_new_length > this.creation_info.max_length )
				throw new LgpError.CROSSOVER_FAILED("The resulting offspring would exceed the maximum length.");

			if( m_new_length < this.creation_info.min_length )
				throw new LgpError.CROSSOVER_FAILED("The resulting offspring would be below the minimum length.");

			Instruction[] m_new_instructions = new Instruction[ m_new_length ];
			int i = 0;
			for( int j = 0 ; j < m_begin ; )
				m_new_instructions[ i++ ] = m[ j++ ];
			for( int j = n_begin ; j < n_end ; )
				m_new_instructions[ i++ ] = n[ j++ ];
			for( int j = m_end ; j < m.length ; )
				m_new_instructions[ i++ ] = m[ j++ ];


			Instruction[] n_new_instructions = new Instruction[ n_new_length ];
			i = 0;
			for( int j = 0 ; j < n_begin ; )
				n_new_instructions[ i++ ] = n[ j++ ];
			for( int j = m_begin ; j < m_end ; )
				n_new_instructions[ i++ ] = m[ j++ ];
			for( int j = n_end ; j < n.length ; )
				n_new_instructions[ i++ ] = n[ j++ ];

			this.program.instructions = m_new_instructions;
			neighbor.program.instructions = n_new_instructions;
		}
		
		void validate ()
		{
			assert( this.program != null );
			assert( this.program.instructions != null );
			assert( this.creation_info.min_length > 0 );
			assert( this.program.length > 0 );
		}
		
		void check ()
		{
			validate ();
			assert( this.program.length >= this.creation_info.min_length );
			assert( this.program.length <= this.creation_info.max_initial_length );
		}
		

		public string refcinfo()
		{
			return "(id:%3d c:%3ld)".printf(this.id, this.ref_count);
		}
	}
	
	










	public class Objectives
	{
		float[] objectives;
	
		public Objectives(int m)
		{
			this.objectives = new float[m];
		}
	
		public Objectives.from_values(float[] os)
		{
			this.objectives = os;
		}
	
		public int length
		{
			get { return this.objectives.length; }
		}
	
		public new float get(int idx)
		{
			return this.objectives[idx];
		}
	
		public new void set(int idx, float val)
		{
			this.objectives[idx] = val;
		}
		
		public float[] to_floats()
		{
			return this.objectives;
		}
		
		public string to_string()
		{
			StringBuilder sb = new StringBuilder();
			foreach( float o in objectives )
			{
				sb.append_printf(" %.3f", o );
			}
			return sb.str;
		}
		
		public bool equals(Objectives o)
		{
			for( int i = 0 ; i < this.objectives.length ; i++ )
			{
				if( this.objectives[i] != o.objectives[i] )
				{
					return false;
				}
			}
			return true;
		}
		
		public Iterator iterator()
		{
			return new Objectives.Iterator(this);
		}
		
		public class Iterator
		{
			int idx;
			Objectives os;
			public Iterator(Objectives o)
			{
				this.os = o;
			}
			public bool next()
			{
				return this.idx < this.os.length;
			}
			public float get()
			{
				return this.os[this.idx++];
			}
		}
	}
	
	
	
	
	
	
	
	
	
	
	public class IndividualFactory
	{
		public static Individual make_from_type(InitilizationType t, ref IndividualSettings si)
		{
			Individual i = null;
			switch( t )
			{
				case InitilizationType.RANDOM: 
					i = new Individual.from_random( si );
					break;

				case InitilizationType.EFF:
					i = new Individual.completely_effective( si );
					break;

				default:
					critical ("Not implemented creation methode for individuals.");
					break;
			}
			
			return i;
		}
	}
}
