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
using GeneticProgramming;

using Gee;

namespace LinearGeneticProgramming
{


	public class SymbolicRegression
	{
		VM vm;
		
		LgpPopulation population;
				
		int maximumGenerations;
		bool request_to_stop;


		public Table train_data;
		public Table test_data;
		

		public Individual[] vips {
			get { return this.population.vips; }
			set { this.population.vips = value; }
		}
			
		public int epoche {
		    get { return this.population.generation; }
		  }

		public signal void on_next_candidates (int g);
		public signal void on_reevaluated ();

		public SymbolicRegression(LgpSettings settings, int maxGenerations, int nworkers)
		{
			this.vm = new InterpretingVM();
			
			this.population = new LgpPopulation(settings);
			this.population.settings = settings;
			this.population.number_of_workers = nworkers;
			
			this.maximumGenerations = maxGenerations;
			this.request_to_stop = false;
			
			connect_signals();
		}
		
		
		void connect_signals()
		{
			/* fitness FUnktion festlegen */
			this.population.objectivesDelegate = (i) => {
				fitnessEvaluation( i );
			};

			/* abbruch kriterium festlegen */
			this.population.terminationDelegate = () => {
				bool is_stop = false;
				lock(this.request_to_stop)
				{
					is_stop = (this.request_to_stop == true);
				}
				return ( is_stop || this.population.generation >= maximumGenerations );
			};
			
			/* signal wenn neue/nächste kandidaten vorliegen */
			this.population.on_generation_begin.connect( (g) => {
				this.on_next_candidates(g);
			});
		}

		public void run() throws Error
		{
			assert (train_data != null && test_data != null);
			
			this.population.run();
		}

		public void stop()
		{
			lock(this.request_to_stop)
			{
				debug("Request to stop received.");
				this.request_to_stop = true;
			}
		}


		/* calculate result from given inputs - FIXME hier compile rein */
		public float[] evaluate( Individual individual, Table inputs, int dst_col = 0 )
		{
			float[] results = new float[ inputs.length ];
			
			for(int i = 0 ; i < inputs.length ; i++ )
			{
				float[] params = inputs[i].to_array();
				params[ dst_col ] = 0;
				results[i] = this.vm.execute( individual.program, params, false )[ dst_col ];
			}

			return results;
		}



		public void fitnessEvaluation( Individual i )
		ensures( i.objectives != null )
		{
			FitnessEvaluationInformation info = null;// i.get_data<FitnessEvaluationInformation>("FitnessEvaluationInformation");

			if( i.objectives == null || info == null )
			{
				/*
				 * 0: Error
				 */
				int dst_col = 0;
				float[] expected = train_data.get_column (dst_col);
				float[] evaluated = evaluate (i, train_data, dst_col );
			
				float err = (float) Statistics.sse_for ( expected, evaluated );
//				float err = (float) Statistics.mse_for ( expected, evaluated );
//				float err = (float) Statistics.rmse_for ( expected, evaluated );
//				float err = (float) Statistics.maximum_difference_in ( expected, evaluated );
//				float err = (float) Statistics.mdl_for ( expected, evaluated, i.program.get_number_of_ops() );

				/*
				 * 1: Size
				 */
//				long fsize = i.size();
				
				string func = i.to_function(); 
//				long fstrlen = func.length;
				long fstrlen = (long) func.length / 3;
//				long ps = Statistics.number_of_not_matching_parenthese (func);
//				long nops = i.program.get_number_of_ops();
//				long dnops = i.program.get_number_of_different_ops();

				long complx = fstrlen;

				i.objectives = new Objectives.from_values({
					err,
					complx
				});
				if(population.settings.SelectionObjectives.length == 1)
				{
					i.selection_objectives = new Objectives.from_values({
						err
					});
				}
				else
				{
					i.selection_objectives = new Objectives.from_values({
						err,
						complx
					});
				}
				
				info = new FitnessEvaluationInformation();
				info.individual = i;
				info.data = train_data;
				info.expected = expected;
				info.evaluated = evaluated;
				info.dl = Statistics.mdl_for ( expected, evaluated, complx );
				
				i.set_data<FitnessEvaluationInformation>("FitnessEvaluationInformation", info);
			}
		}
		
		public float[] testAllEvaluation (Individual i)
		{
			return evaluateAll (i, ref this.test_data);
		}
		
		public float[] trainAllEvaluation (Individual i)
		{
			return evaluateAll (i, ref this.train_data);
		}
		
		float[] evaluateAll (Individual i, ref Table edata)
		{
			float[] tr = new float[ObjectiveType.COUNT];
			
			int dst_col = 0;
			float[] expected = edata.get_column (dst_col);
			float[] evaluated = evaluate (i, edata, dst_col );
		
			tr[ObjectiveType.SSE] = (float) Statistics.sse_for (expected, evaluated);
			tr[ObjectiveType.MSE] = (float) Statistics.mse_for (expected, evaluated);
			tr[ObjectiveType.RMSE] = (float) Statistics.rmse_for (expected, evaluated);
			tr[ObjectiveType.R_SQUARE] = (float) Statistics.r_square_for (expected, evaluated);
			tr[ObjectiveType.MIN_ERROR] = (float) Statistics.minimum_error_of (expected, evaluated);
			tr[ObjectiveType.MAX_ERROR] = (float) Statistics.maximum_error_of (expected, evaluated);

			tr[ObjectiveType.LEN_FORMULA] = i.to_function ().length;
			tr[ObjectiveType.LEN_FORMULA_ONE_THIRD] = i.to_function ().length / 3;
			tr[ObjectiveType.LEN_PROGRAM] = i.size ();
			
			return tr;
		}
		
		public Individual individual_from_instructions (string[] f)
		{
			return this.population.individual_from_instructions (f);
		}
		
		public Individual[] get_candidates()
		{
			return this.population.get_individuals ();
		}
		

		public LgpStatistics getStatistics()
		{
			return this.population.getStatistics();
		}

		public static LgpSettings get_default_settings()
		{
			return LgpSettings() {
				PopulationSize = 5000,
				NumberOfDemes = 10,
				MigrationRate = 0.05,
				MigrationInterval = 0,
				MaximumNumberOfGenerations = 1000,
				MinimumProgramLength = 5,
				MaximumProgramLength = 50,
				MaximumInitialLength = 55,
				TournamentSize = 2,
				CrossoverProbability = 0.1,
				MutationProbability = 0.9,
				InstructionSet = new Operation[]{ 
					Operation.Add, Operation.Sub
					, Operation.Mul, Operation.Div
					, Operation.Pow
					, Operation.Sqrt
				},
				RegisterSet = 10,
				CalculationSet = 0,
				ConstantSet = 255,
				SelectionType = SelectionType.NSGA2_DEB,
				SelectionObjectives = { ObjectiveType.SSE, ObjectiveType.LEN_FORMULA_ONE_THIRD },
				StatisticObjectives = { ObjectiveType.SSE, ObjectiveType.LEN_FORMULA_ONE_THIRD, ObjectiveType.TRAIN_SSE }
			};
		}
	}
}

