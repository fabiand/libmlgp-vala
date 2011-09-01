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


namespace VirtualMachine
{

	public class Instruction
	{
		public int dst;
		public Operation operation;
		public int r1;
		public int r2;

		public Instruction.with(int d, Operation o, int r1, int r2)
		{
			this.dst = d;
			this.operation = o;
			this.r1 = r1;
			this.r2 = r2;
		}

		public Instruction.try_parse (string s)
		{
			Regex expr = /r[0-9]+ = [^\s]+ r[0-9]+ r[0-9]+/;
			
			if (expr.match(s))
			{
				string[] ts = /\s+/.split (s);
				assert (ts.length == 5);
				this.dst = int.parse (ts[0].replace ("r",""));
				this.operation = Operation.try_parse (ts[2].strip());
				this.r1 = int.parse (ts[3].replace ("r",""));
				this.r2 = int.parse (ts[4].replace ("r",""));
			}
		}

		public Instruction clone()
		{
			Instruction ins = new Instruction.with(
				this.dst,
				this.operation,
				this.r1,
				this.r2
				);
			return ins;
		}

		public string to_string()
		{
				return "r%d = %s r%d r%d".printf(
					this.dst,
					OperationStr[ this.operation ], 
					this.r1,
					this.r2
				);
		}
	}

	public class InstructionsConfiguration
	{
		public Operation[] used_ops;
		public int no_of_vars;
		public int no_of_calcs;
		public int no_of_consts;
	}


	public class Program
	{
		public Instruction[] instructions;
		
		public Operation[] used_ops;
		public int no_of_vars;
		public int no_of_calcs;
		public int no_of_consts;

		public int length {
			get { return this.instructions.length; }
		}

		public int no_of_registers {
			get { return this.no_of_vars + this.no_of_calcs + this.no_of_consts; }
		}

		public Program(int size)
		{
			this.instructions = new Instruction[ size ];
		}
		
		public Program.try_parse (string[] ts, Operation[]? ops = null, int nvars = 0, int ncalcs = 0, int nconsts = 0)
		{
//			string[] ts = /[\n;]+/.split (s);
			
			this.instructions = new Instruction[ ts.length ];
			this.no_of_vars = nvars;
			this.no_of_calcs = ncalcs;
			this.no_of_consts = nconsts;
			
			for (int i = 0; i < this.instructions.length; i++)
			{
				this.instructions[i] = new Instruction.try_parse (ts[i]);
			}
			
			Operation[] my_used_ops = new Operation[0];
			
			// Add each op once
			foreach (unowned Instruction i in this.instructions)
			{
				bool in_array = false;
				foreach (unowned Operation uo in this.used_ops)
				{
					if (i.operation == uo)
						in_array = true;
				}
				if (!in_array)
				{
					my_used_ops += i.operation;
				}
			}
			if (ops != null)
			{
				// Add each op once
/*				string[] tos = /[\s\n;]+/.split (ops);
				foreach (unowned string i in tos)
				{
					bool in_array = false;
					Operation po = Operation.try_parse (ops);
					foreach (unowned Operation uo in this.used_ops)
					{
						if (po == uo)
							in_array = true;
					}
					if (!in_array)
					{
						my_used_ops += po;
					}
				}*/
				foreach (Operation o in ops)
				{
					bool in_array = false;
					foreach (unowned Operation uo in this.used_ops)
					{
						if (o == uo)
							in_array = true;
					}
					if (!in_array)
					{
						my_used_ops += o;
					}
				}
			}
			this.used_ops = my_used_ops;
		}

		public inline Instruction get(int idx)
		{
			return this.instructions[ idx ];
		}

		public inline void set(int idx, Instruction v)
		{
			this.instructions[ idx ] = v;
		}

		public Program clone()
		{
			Program ins = new Program(this.length);

			for( int i = 0 ; i < this.length ; i++ )
			{
				ins.instructions[i] = this.instructions[i].clone();
			}

			ins.used_ops = this.used_ops;
			ins.no_of_vars = this.no_of_vars;
			ins.no_of_calcs = this.no_of_calcs;
			ins.no_of_consts = this.no_of_consts;
			return ins;
		}

		public string to_string()
		{
			StringBuilder sb = new StringBuilder();
			foreach( unowned Instruction i in this.instructions )
			{
				sb.append( i.to_string() + "\n" );
			}
			return sb.str;
		}
		
		public int get_number_of_ops ()
		{
			int n = 0;
			foreach (unowned Instruction i in this.instructions)
			{
				if (UnaryOperation[i.operation])
				{
					n += 1 + 1;
				}
				else
				{
					n += 1 + 2;
				}
			}
			return n;
		}
		
		public int get_number_of_different_ops ()
		{
			int n = 0;
			bool[] ops, regs;
			ops = new bool[ Operation.LENGTH ];
			regs = new bool[ this.no_of_registers ];
			assert (ops[0] == false);
			assert (regs[0] == false);
			
			foreach (unowned Instruction i in this.instructions)
			{
				ops[i.operation] = true;
				regs[i.r1] = true;
				if (!UnaryOperation[i.operation])
				{
					regs[i.r2] = true;
				}
			}

			foreach (bool b in ops)
				if (b)
					n++;
			foreach (bool b in regs)
				if (b)
					n++;
			
			return n;
		}

		public void insert_instruction( int position, Instruction instruction)
		{
			insert_instructions( position, new Instruction[] { instruction } );
		}

		public void insert_instructions( int position, Instruction[] additional_instructions )
		{
			assert( position <= this.instructions.length );
			
			Instruction[] new_instructions = new Instruction[ this.length + additional_instructions.length ];

			for( int i = 0 ; i < new_instructions.length ; i++ )
			{
				if( i < position )
				{
					new_instructions[ i ] = this.instructions[ i ];
				}
				else if( i < position + additional_instructions.length )
				{
					new_instructions[ i ] = additional_instructions[ i - position ];
				}
				else
				{
					new_instructions[ i ] = this.instructions[ i - additional_instructions.length ];
				}
			}

			this.instructions = new_instructions;
		}

		public void replace_with_instructions( int position, int rlength, Instruction[] replacement_instructions )
		{
			assert( position <= this.instructions.length );
			
			Instruction[] new_instructions = new Instruction[ this.length - rlength + replacement_instructions.length ];

			int j = 0, k = 0;
			for( int i = 0 ; i < new_instructions.length ; i++ )
			{
				if( i < position )
				{
					new_instructions[ i ] = this.instructions[ j++ ];
				}
				else if( i < position + replacement_instructions.length )
				{
					new_instructions[ i ] = replacement_instructions[ k++ ];
				}
				else
				{
					new_instructions[ i ] = this.instructions[ j++ ];
				}
			}

			this.instructions = new_instructions;
		}

		public void delete_instruction( int position )
		{
			if( this.instructions.length == 0 ) return;
			// FIXME kann insgesamt durch replace ersetzt werden
			assert( position < this.instructions.length );
			
			Instruction[] new_instructions = new Instruction[ this.length - 1 ];

			int k = 0;
			for( int i = 0 ; i < this.instructions.length ; i++ )
			{
				if( i != position )
				{
					new_instructions[ k++ ] = this.instructions[ i ];
				}
			}

			this.instructions = new_instructions;
		}

		/*
		 * Algorithm 3.1 detection of structural introns
		 */
		bool[] markerEffectiveInstructions()
		{
			bool[] Reff   = new bool[ this.no_of_registers ],
				   Marker = new bool[ this.length ];

			if( this.length == 0 )
			{
				return Marker;
			}
		
			assert(Reff[0] == false && Marker[0] == false);
		
			// Initial ist nur das pseudo-out-Register aktiv.
			Reff[0] = true;
		
		
			for( int i = this.length-1 ; i >= 0 ; i-- )
			{
				if( Reff[ this.instructions[ i ].dst ] == true )
				{
					Marker[ i ] = true;
					Reff[ this.instructions[ i ].dst ] = false;
				
					Reff[ this.instructions[ i ].r1 ] = true;
					Reff[ this.instructions[ i ].r2 ] = true;
				}
			}
		
			return Marker;
		}
		
		public Instruction[] getEffectiveInstructions()
		{
			bool[] Marker = this.markerEffectiveInstructions();
			
			Instruction[] ins_eff = {};
			for( int i = 0 ; i < this.length ; i++ )
			{
				if( Marker[ i ] == true )
				{
					ins_eff += this.instructions[ i ];
				}
			}

			return ins_eff;
		}

		public void makeEffective()
		{
			this.instructions = this.getEffectiveInstructions();
		}
		
		
		/*
		 * Algorithm 3.2 elimination of semantic introns
		 */
		 /*public Instruction[] withoutSemanticIntrons()
		 {
		 	
		 }*/
	}
}
