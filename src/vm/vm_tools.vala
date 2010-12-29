/* vim: set ts=4 tw=4: */

namespace VirtualMachine
{

	public int rint(int max)
	{
		return max == 0 ? 0 : Random.int_range(0, max);
	}

	public Program create_random_program(int min_length, int max_length, Operation[] used_ops, int no_of_vars, int no_of_calcs, int no_of_consts)
	{
		int ins_length = min_length + rint(max_length-min_length);
		
		Program ins = new Program(ins_length);
		ins.used_ops = used_ops;
		ins.no_of_vars = no_of_vars;
		ins.no_of_calcs = no_of_calcs;
		ins.no_of_consts = no_of_consts;

		for( int i = 0 ; i < ins_length ; i++ )
		{
			Instruction a = create_random_instruction( used_ops, no_of_vars, no_of_calcs, no_of_consts );
			ins.instructions[i] = a;
		}

		assert( ins.length >= min_length && ins.length <= max_length );
		
		return ins;
	}

	public Program create_effective_program(int min_length, int max_length, Operation[] used_ops, int no_of_vars, int no_of_calcs, int no_of_consts)
	{
		int ins_length = min_length + rint(max_length-min_length);
		
		Program ins = new Program(ins_length);
		ins.used_ops = used_ops;
		ins.no_of_vars = no_of_vars;
		ins.no_of_calcs = no_of_calcs;
		ins.no_of_consts = no_of_consts;

		List<int> Reff = new List<int>();
		Reff.append( 0 );
		
		for( int i = ins_length-1 ; i >= 0 ; i-- )
		{
			Instruction a = create_random_instruction( used_ops, no_of_vars, no_of_calcs, no_of_consts );

			int n_dst = rint((int)Reff.length()); // first time will always be 0
			a.dst = Reff.nth_data( n_dst );

			Reff.remove( a.dst );
			if( Reff.index( a.r1 ) < 0 ) Reff.append( a.r1 );
			if( Reff.index( a.r2 ) < 0 ) Reff.append( a.r2 );
						
			ins.instructions[i] = a;
		}

		assert( ins.length >= min_length && ins.length <= max_length );
		
		return ins;
	}

	public Instruction create_random_instruction(Operation[] used_ops, int no_of_vars, int no_of_calcs, int no_of_consts)
	{
		Instruction a = new Instruction();
		a.dst = rint( no_of_vars + no_of_calcs );
		a.operation = used_ops[ rint( used_ops.length ) ];
		if( Random.boolean() )
		{
			a.r1 = rint( no_of_vars );
		}
		else
		{
			a.r1 = rint( no_of_calcs + no_of_consts );
		}
//		a.r1 = rint( no_of_vars + no_of_calcs + no_of_consts );
		if( Random.boolean() )
		{
			a.r2 = rint( no_of_vars );
		}
		else
		{
			a.r2 = rint( no_of_calcs + no_of_consts );
		}
//		a.r2 = rint( no_of_vars + no_of_calcs + no_of_consts );
		return a;
	}

	/*
	l	2k,2k+1
	0	
	1	2,3
	2	4,5
	3	6,7
	*/
	public Program create_treeized_program(int min_length, int max_length, Operation[] used_ops, int no_of_vars, int no_of_consts)
	{
		int ins_length = min_length + rint(max_length-min_length);
		
		Program ins = new Program(ins_length);
		ins.used_ops = used_ops;
		ins.no_of_consts = no_of_consts;
		ins.no_of_vars = no_of_vars;
//		ins.no_of_calcs = 2; // 2 als temp f"ur odd und even

		
		int dst_reg_odd = ins.no_of_registers - 1, 
		    dst_reg_even = ins.no_of_registers - 2;
		
		for( int i = 0 ; i < ins_length ; i++ )
		{
			Instruction a = new Instruction();
			a.dst = (i == 0) ? 0 :
					(i % 2 == 0) ? dst_reg_even : dst_reg_odd;
			a.operation = used_ops[ rint( used_ops.length ) ];
			a.r1 = (i == ins_length - 1) ? rint(ins.no_of_registers-2) : dst_reg_odd;
			a.r2 = (i == ins_length - 1) ? rint(ins.no_of_registers-2) : dst_reg_even;
			ins.instructions[ ins_length-i-1 ] = a;
		}

		assert( ins.length >= min_length && ins.length <= max_length );
		
		return ins;
	}


	public string dump( Program ins, string[]? alias )
	{
		if( alias != null && alias.length < ( ins.no_of_consts + ins.no_of_vars ) )
		{
			warning("Not enough aliases given. %d given and %d expected.", 
				alias.length,
				( ins.no_of_consts + ins.no_of_vars )
			);
			alias = null;
		}
		string str = ins.to_string();
		if( alias != null ) substitute_registers( ref str, alias );
		return str;
	}

	public string flatten( Program ins, int dst_reg = 0, string[]? alias )
	{
		string[] regs = new string[ ins.no_of_registers ];
		for( int i = 0 ; i < regs.length ; i++ ) regs[i] = "r" + i.to_string();
		
		foreach(Instruction i in ins.instructions)
		{
			if( UnaryOperation[i.operation] )
			{
				regs[ i.dst ] = OperationStr[i.operation].printf(
					regs[ i.r1 ]
				);
			}
			else
			{
				regs[ i.dst ] = "(%s%s%s)".printf(
					regs[ i.r1 ], 
					OperationStr[i.operation],
					regs[ i.r2 ]
				);
			}
		}
		string str = regs[ dst_reg ];
		if( alias != null ) substitute_registers( ref str, alias );
		return str;
	}
	
	void substitute_registers(ref string str, string[] alias)
	{
		try
		{
			// FIXME vllt mit replace_eval machen?
			for( int i = alias.length-1 ; i >=0  ; i-- )
			{
				Regex re = new Regex(@"r$(i)", RegexCompileFlags.MULTILINE);
				str = re.replace(str, str.length, 0, alias[i]);
			}
		} catch(Error e) {
			critical(e.message);
		}
	}
	
	
	public Instruction[]? parse_formula (string f)
	{
		Instruction[] ins = new Instruction[0];
		
		Regex expr_unary = /^[\w\d]+\([\w\d()+\*\/-]*\)/;
		
		if (expr_unary.match(f))
		debug("hi");
		else
		debug("poh");
		
		return ins;
	}
}
