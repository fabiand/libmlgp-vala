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


// http://www.geekbeing.com/2010/08/20/shunting-yard-algorithm-implementation-in-c/

using Gee;

namespace Dijkstra
{

	public class ShuntingYard
	{
		Gee.Queue<string> output;
		Gee.Deque<string> operators;
		
		public ShuntingYard ()
		{
			this.init ();
		}
			
		void init ()
		{
			this.output = new LinkedList<string> ();
			this.operators = new LinkedList<string> ();
		}
		
		/*
		 * Dijkstra's original
		 */
		public string original (string infix)
		{
			this.init ();
			
			string postfix = "";
			
			string[] tokens = /[[:space:]]+/.split (infix);
			
			foreach (unowned string _token in tokens)
			{
				string token = _token.strip ();
				
				if (is_number (token))
				{
					this.output.offer (token);
				}
				else if (is_function (token))
				{
					this.operators.offer_head (token);
				}
				else if (is_function_argument_separator (token))
				{
					while (this.operators.size > 0 && (this.operators.peek_head () != "("))
					{
						this.output.offer (this.operators.poll_head ());
					}
				}
				else if (is_operator (token))
				{
					while (operators.size > 0 && is_operator (this.operators.peek_head ()))
					{
						if ((is_left_associative (token) && this.operators.size > 0 && (precedence_of (token) <= precedence_of (this.operators.peek_head ()))) || 
						    (is_right_associative (token) && this.operators.size > 0 && (precedence_of (token) < precedence_of (this.operators.peek_head ()))))
						{
							this.output.offer (this.operators.poll_head ());
						}
						else
						{
							break;
						}
					}
					this.operators.offer_head (token);
				}
				if (token == "(")
				{
					this.operators.offer_head (token);
				}
				if (token == ")")
				{
					while (this.operators.size > 0 && this.operators.peek_head () != "(")
					{
						this.output.offer (this.operators.poll_head ());
					}
					this.operators.poll_head ();
				}
				if (this.operators.size > 0 && is_function (this.operators.peek_head ()))
				{
					this.output.offer (this.operators.poll_head ());
				}
			}
			while (this.operators.size > 0 && is_operator (this.operators.peek_head ()))
			{
				this.output.offer (this.operators.poll_head ());
			}
			while (this.output.size > 0)
			{
				postfix += this.output.poll () + " ";
			}
			return postfix.strip ();
		}
		
		
		/*
		 * Slightly modified
		 * http://www.chris-j.co.uk/parsing.php
		 */
		public string transform_infix_to_postfix (string infix)
		{
			this.init ();
			
			string postfix = "";
			
			string[] tokens = /[[:space:]]+/.split (infix.strip ());
			
			foreach (unowned string _token in tokens)
			{
				string token = _token.strip ();
				
				if (is_operand (token))
				{
					this.output.offer (token);
				}
				else if (is_unary_postfix_operator (token))
				{
					this.output.offer (token);
				}
				else if (is_unary_prefix_operator (token))
				{
					this.operators.offer_head (token);
				}
				else if (is_function (token))
				{
					this.operators.offer_head (token);
				}
				else if (is_function_argument_separator (token))
				{
					while (this.operators.size > 0 && (this.operators.peek_head () != "("))
					{
						this.output.offer (this.operators.poll_head ());
					}
				}
				else if (is_binary_operator (token))
				{
					while (operators.size > 0)
					{
						if ((is_left_associative (token) && this.operators.size > 0 && (precedence_of (token) <= precedence_of (this.operators.peek_head ()))) || 
						    (is_right_associative (token) && this.operators.size > 0 && (precedence_of (token) < precedence_of (this.operators.peek_head ()))))
						{
							this.output.offer (this.operators.poll_head ());
						}
						else
						{
							break;
						}
					}
					this.operators.offer_head (token);
				}
				else if (token == "(")
				{
					this.operators.offer_head (token);
				}
				else if (token == ")")
				{
					while (this.operators.size > 0 && this.operators.peek_head () != "(")
					{
						this.output.offer (this.operators.poll_head ());
					}
					this.operators.poll_head ();
				}
				else if (this.operators.size > 0 && is_function (this.operators.peek_head ()))
				{
					this.output.offer (this.operators.poll_head ());
				}
			}
			
			while (this.operators.size > 0)
			{
				this.output.offer (this.operators.poll_head ());
			}
			
			while (this.output.size > 0)
			{
				postfix += this.output.poll () + " ";
			}
			return postfix.strip ();
		}
		
		bool is_number (string s)
		{
			return /^[[:digit:].]+$/.match(s);
		}
		
		bool is_variable (string s)
		{
			return /^[[:alpha:]]+$/.match(s) &&  !is_function (s);
		}
		
		bool is_operand (string s)
		{
			return is_number (s) || is_variable (s);
		}
		
		bool is_operator (string s)
		{
			return is_unary_prefix_operator (s) || is_unary_postfix_operator (s) || is_binary_operator (s);
		}
		
		bool is_unary_prefix_operator (string s)
		{
			return s in "-";
		}
		
		bool is_unary_postfix_operator (string s)
		{
			return s in "!";
		}
		
		bool is_binary_operator (string s)
		{
			return s in "+-*/^";
		}

		bool is_parenthesis (string s)
		{
			return s in "()";
		}
		
		bool is_function_argument_separator (string s)
		{
			return s in ",";
		}
		
		bool is_function (string s)
		{
			return s in new string[] {"sin","cos","tan","sqrt","pow","exp"};
		}
		
		bool is_left_associative (string s)
		{
			return ! is_right_associative (s);
		}
		
		bool is_right_associative (string s)
		{
			return s in "^";
		}
		
		int precedence_of (string s)
		{
			int r = -1;
			if (is_function (s)) r = 7;
			if (s in "+-") r = 2;
			if (s in "*/") r = 3;
			if (s in "^") r = 5;
			if (is_unary_prefix_operator (s)) r = 6;
			return r;
		}
		
		
		
		public string postfix_to_program (string postfix, HashTable<string,int>? operand_to_register = null)
		{
			this.init ();
			int n_dst = 1,
			    n_vars = 0, // später
			    n_calcs = 1,
			    n_consts = 0; // später
			
			Gee.Queue<string> operands = new LinkedList<string> ();
			
			string p = "";
	
			string[] tokens = postfix.strip ().split (" ");
			
			foreach (unowned string token in tokens)
			{
				if (is_number (token)) n_consts++;
				if (is_variable (token)) n_vars++;
			}
			
			int c_vars = n_dst,
			    c_calcs = n_dst + n_vars,
			    c_consts = n_dst + n_vars + n_calcs;
			
			foreach (unowned string token in tokens)
			{
				if (is_number (token) || is_variable (token))
				{
					operands.offer (token);
				}
				else if (is_binary_operator (token) || is_function (token))
				{
					assert (operands.size <= 2);
					
					int op1, op2;
					if (is_number (operands.poll ()))
					{
						op1 = c_consts;
						c_consts++;
					}
					else
					{
						op1 = c_vars;
						c_vars++;
					}

					if (operands.size == 1)
					{
						if (is_number (operands.poll ()))
						{
							op2 = c_consts;
							c_consts++;
						}
						else
						{
							op2 = c_vars;
							c_vars++;
						}
					}
					else
					{
						op2 = c_calcs;
					}
					
					p += "r%d = %s r%d r%d;\n".printf (
						c_calcs,
						token,
						op1,
						op2
					);
				}
			}
			
			return p;
		}
		
		
		public string postfix_to_orc_program (string postfix)
		{
			this.init ();
			
			int n_dst = 1,
			    n_vars = 0, // später
			    n_calcs = 1,
			    n_consts = 0; // später
			
			Gee.Queue<string> operands = new LinkedList<string> ();
			Gee.Set<string> vars = new TreeSet<string> ();
			
			string p = "";
	
			string[] tokens = postfix.strip ().split (" ");
			
			foreach (unowned string token in tokens)
			{
				if (is_number (token)) n_consts++;
				if (is_variable (token)) 
				{
					n_vars++;
					vars.add (token);
				}
			}
			
			int c_vars = n_dst,
			    c_calcs = n_dst + n_vars,
			    c_consts = n_dst + n_vars + n_calcs;
			
			foreach (unowned string token in tokens)
			{
				if (is_number (token) || is_variable (token))
				{
					operands.offer (token);
				}
				else if (is_binary_operator (token) || is_function (token))
				{
					assert (operands.size <= 2);
					
					int op1, op2;
					if (is_number (operands.poll ()))
					{
						op1 = c_consts;
						c_consts++;
					}
					else
					{
						op1 = c_vars;
						c_vars++;
					}

					if (operands.size == 1)
					{
						if (is_number (operands.poll ()))
						{
							op2 = c_consts;
							c_consts++;
						}
						else
						{
							op2 = c_vars;
							c_vars++;
						}
					}
					else
					{
						op2 = c_calcs;
					}
					
					p += "r%d = %s r%d r%d;\n".printf (
						c_calcs,
						token,
						op1,
						op2
					);
				}
			}
			
			return p;
		}
	}
}







