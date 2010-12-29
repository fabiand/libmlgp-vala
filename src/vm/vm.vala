/* vim: set ts=4 tw=4: */


namespace VirtualMachine
{

	public enum Operation {
		Add,
		Sub,
		Mul,
		Div,
		Pow,
		Exp,
		Sin,
		Cos,
		Sqr,
		Tan,
		Sqrt,
		Sgn,
		Log_e,
		LENGTH;
		
		public static Operation? try_parse (string os)
		{
			Operation? o = null;
			for (int i = 0; i < Operation.LENGTH; i++)
			{
				if (OperationStr[i].has_prefix(os))
				{
					o = (Operation) i;
					break;
				}
			}
			return o;
		}
		
		public static Operation[] try_parse_all (string[] oss)
		{
			Operation[] ops = new Operation[0];
			
			foreach (unowned string os in oss)
			{
				Operation? op = Operation.try_parse (os);
				if (op != null)
				{
					ops += op;
				}
			}
			
			return ops;
		}
		
		
	}
	public const string[] OperationStr = {
		"+", "-", "*", "/", "^", 
		"exp(%s)", "sin(%s)", "cos(%s)", "pow(%s,2)", "tan(%s)", "sqrt(%s)", "sgn(%s)", "log_e(%s)"
	};
	public const bool[] UnaryOperation = {
		false, false, false, false, false,
		true, true, true, true, true, true, true, true
	};

	
	public abstract class VM
	{
		[CCode (has_target = false)]
		protected delegate float DelegateOperation(float a, float b);

		public void validate( Program p, float[] inputs )
		{
			int expected_length = p.no_of_registers;
			assert( p.instructions != null );
			assert( inputs != null );
			assert( expected_length == inputs.length );
		}

		public abstract Function compile( Program p );
		
		public abstract float[] execute( Program p, float[] inputs, bool do_optimize = false );
	}


	public class Function
	{
		VM vm;
		Program program;

		public Function(VM vm, Program p)
		{
			this.vm = vm;
			this.program = p;
		}

		public float[] eval( float[] inputs )
		{
			int expected_length = program.no_of_registers;
			assert( inputs.length == expected_length );
			return this.vm.execute( this.program, inputs );
		}

		public string to_string(string[]? alias = null)
		{
			int dst = 0;

			string[] aliases = new string[ program.no_of_registers ];

			int j = 0;
			
			if( alias != null )
			{
				assert( alias.length == program.no_of_vars );
				for( int i = 0 ; i < program.no_of_vars ; i++ )
				{
					aliases[ j++ ] = alias[ i ];
				}
			}
			else
			{
				for( int i = 0 ; i < program.no_of_vars; i++ )
				{
					aliases[ j++ ] = ((char)(97 + i)).to_string(); //alias[ i ];
				}
			}
			for( int i = 0 ; i < program.no_of_calcs ; i++ )
			{
				aliases[ j++ ] = "1";
			}
			for( int i = 0 ; i < program.no_of_consts; i++ )
			{
				aliases[ j++ ] = i.to_string();
			}
//			foreach(string s in aliases) print("%s \n", s);
			return flatten( this.program, dst, aliases);
		}

		public void to_file(string filename, string[]? alias = null)
		{
			File f = File.new_for_path( filename );
			string str = this.to_string(alias);
			
			try {
				f.replace_contents( str, str.length, "", false, 0, null, null );
			} catch(Error e) {
				debug(@"Writing data to '$filename'.");
				error(e.message);
			}
		}
	}

	public class InterpretingVM : VM
	{
		static float add(float a, float b) { return a + b; }
		static float sub(float a, float b) { return a - b; }
		static float mul(float a, float b) { return a * b; }
		static float div(float a, float b) { return a / b; }
		static float pow(float a, float b) { return Math.powf(a, b); }
		static float exp(float a, float dummy) { return (float) Math.exp(a); }
		static float sin(float a, float dummy) { return (float) Math.sin(a); }
		static float cos(float a, float dummy) { return (float) Math.cos(a); }
		static float tan(float a, float dummy) { return (float) Math.tan(a); }
		static float sqr(float a, float dummy) { return (float) Math.powf(a, 2); }
		static float sqrt(float a, float dummy) { return (float) Math.sqrtf(a); }
		static float sgn(float a, float dummy) { return (float) ((a > 0) ? 1 : ((a < 0) ? -1 : 0)); }
		static float log_e(float a, float dummy) { return (float) Math.log(a); }
		
		/* Contains just those ops which this vm supports */
		VM.DelegateOperation[] available_ops = { 
			add, sub, mul, div, pow, 
			exp, sin, cos, sqr, tan, sqrt, sgn, log_e
		};

		public InterpretingVM()
		{
		}
		
		public override Function compile( Program p )
		{
			return new Function( this, p.clone() );
		}
		
		public override float[] execute( Program p, float[] inputs, bool do_optimize = false )
		{
			this.validate(p, inputs);

			Program workingset = p;
			
			float[] _v = new float[ inputs.length + workingset.no_of_calcs ];
			for( int i = 0; i < inputs.length ; i++ ) _v[i] = inputs[i];

			if( do_optimize )
			{
				workingset = optimize( workingset );
			}
		
			foreach( unowned Instruction a in workingset.instructions )
			{
				_v[ a.dst ] = available_ops[a.operation](
					_v[ a.r1 ],
					_v[ a.r2 ]
					);
			}
			return _v;
		}
	}

	Program optimize( Program p )
	{
/*		Program optimized = p.clone();

		if( optimized.length != 0 )
		{
	 		removeStructuralIntrons( p );
 		}*/
 		
		return p; //optimized;
	}

	/*void removeStructuralIntrons( Program p )
 	{
		bool[] Reff   = new bool[ p.no_of_registers ],
		       Marker = new bool[ instructionset.length ];
		int new_instructionset_size = 0;
		
		assert( instructionset.length == 0 || ( Reff[0] == false && Marker[0] == false ) );
		
		// Initial ist nur das pseudo-out-Register aktiv.
		Reff[0] = true;
		
		for( int i = instructionset.length-1 ; i >= 0 ; i-- )
		{
			if( Reff[ instructionset.instructions[ i ].dst ] == true )
			{
				Marker[ i ] = true;
				new_instructionset_size++;
				
				Reff[ instructionset.instructions[ i ].dst ] = false;
				
				if( Reff[ instructionset.instructions[ i ].r1 ] == false )
				{
					Reff [ instructionset.instructions[ i ].r1 ] = true;
				}
 
				if( ! instructionset.instructions[ i ].r2_is_val )
				{
					Reff[ instructionset.instructions[ i ].r2 ] = true;
				}
			}
		}

		int c = 0;
		Instruction[] ins = new Instruction[ new_instructionset_size ];
		for( int i = 0 ; i < instructionset.length ; i++ )
 		{
			if( Marker[ i ] == true )
			{
				ins[ c++ ] = instructionset.instructions[ i ];
			}
 		}

 		instructionset.instructions = ins;
 	}*/
}
