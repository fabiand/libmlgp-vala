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

namespace GeneticProgramming
{

	public enum ObjectiveType
	{
		/* Error */
		SSE,
		MSE,
		RMSE,
		R_SQUARE,
		MIN_ERROR,
		MAX_ERROR,
		
		TRAIN_SSE,
		
		/* Complexity */
		LEN_FORMULA,
		LEN_FORMULA_ONE_THIRD,
		LEN_PROGRAM,
		
		COUNT;
		
		public static string summarize (float[] vals)
		{
			StringBuilder sb = new StringBuilder();
			
			for (int i = 0 ; i < ObjectiveType.COUNT; i++)
			{
				sb.append_printf ("%s: %.4f\n", ((ObjectiveType) i).to_string(), vals[i]);
			}
			
			return sb.str;
		}
	}

	public enum SelectionType
	{
		NONE,
		LGP_MATING,
/*		NSGA2_PISA,*/
		NSGA2_DEB
	}

	public enum InitilizationType
	{
		RANDOM,
		EFF
	}

	public enum CrossoverType
	{
		_ONEPOINT,
		_TWOPOINT,
		CROSS,
		EFFCROSS,
		ONSEGMUT
	}

	public enum MutationType
	{
		_SIMPLE,
		MUT,
		EFFMUT,
		NEUTREFFMUT
	}

	/*
	 * Settings
	 */
	public struct IndividualSettings
	{
		int min_length;
		int max_length;
		int max_initial_length;
		Operation[] used_ops;
		int no_of_vars;
		int no_of_calcs;
		int no_of_consts;
	}
	
	public struct LgpSettings
	{
		int PopulationSize;
		int NumberOfDemes;
		double MigrationRate;
		int MigrationInterval;
		int MaximumNumberOfGenerations;
		int MinimumProgramLength;
		int MaximumProgramLength;
		int MaximumInitialLength;
		int TournamentSize;
		double CrossoverProbability;
		double MutationProbability;
		Operation[] InstructionSet;
		int RegisterSet;
		int CalculationSet;
		int ConstantSet;
		
		SelectionType SelectionType;
		ObjectiveType[] SelectionObjectives;
		
		/* To evaluate, for statistics */
		ObjectiveType[] StatisticObjectives;
		
		public string to_string ()
		{
		    string r = @"
PopulationSize: $(this.PopulationSize)
NumberOfDemes: $(this.NumberOfDemes)
MigrationRate: $(this.MigrationRate)
MigrationInterval: $(this.MigrationInterval)
MaximumNumberOfGenerations: $(this.MaximumNumberOfGenerations)
MinimumProgramLength: $(this.MinimumProgramLength)
MaximumProgramLength: $(this.MaximumProgramLength)
MaximumInitialLength: $(this.MaximumInitialLength)
TournamentSize: $(this.TournamentSize)
CrossoverProbability: $(this.CrossoverProbability)
MutationProbability: $(this.MutationProbability)
SelectionType: $(this.SelectionType)
";
            return r;
		}
	}
	
/*	subpopulation LgpSettings() {
		PopulationSize = 5000,
		NumberOfDemes = 10,
		MigrationRate = 0.05,
		MaximumNumberOfGenerations = 250,
		MinimumProgramLength = 5,
		MaximumProgramLength = 256,
		MaximumInitialLength = 25,
		TournamentSize = 2,
		CrossoverProbability = 0.9,
		MutationProbability = 0.25,
		InstructionSet = new Operation[]{ Operation.Add, Operation.Sub, Operation.Mul, Operation.Div, Operation.Pow },
		RegisterSet = 10,
		ConstantSet = 255
	}*/
	
/*	population LgpSettings() {
		PopulationSize = 5000,
		NumberOfDemes = 10,
		MigrationRate = 0.05,
		MaximumNumberOfGenerations = 250,
		MinimumProgramLength = 1,
		MaximumProgramLength = 256,
		MaximumInitialLength = 25,
		TournamentSize = 2,
		CrossoverProbability = 0.9,
		MutationProbability = 0.9,
		InstructionSet = new Operation[]{ Operation.Add, Operation.Sub, Operation.Mul, Operation.Div },
		RegisterSet = 10,
		ConstantSet = 255
	}*/

	
	
	public class FitnessEvaluationInformation : Object
	{
		public unowned Individual individual;
		public Table data;
		public float[] expected;
		public float[] evaluated;
		public double dl;
	}
	
	
	public errordomain LgpError
	{
		CROSSOVER_FAILED
	}


	public struct TournamentResult
	{
		unowned Individual winner;
		unowned Individual looser;
	}

	public struct LgpStatistics
	{
		string desc;
		int num_individuals;
		
		ObjectiveStatistics[] objectiveStatistics;

		double[] times;
		
		public string to_string()
		{
			StringBuilder sb = new StringBuilder();
			sb.append_printf("Statistics: %s \n\tNumber of individuals: %d\n\tTimes: ", desc, num_individuals);
			foreach(double d in this.times)
			{
				sb.append_printf("%.5f\t", d);
			}
			sb.append("\n\tObjectives:\n");
			foreach( unowned ObjectiveStatistics os in objectiveStatistics)
			{
				sb.append( "\t" + os.to_string() + "\n" );
			}
			return sb.str;
		}
		
		public string to_csv()
		{
			StringBuilder sb = new StringBuilder();
			sb.append_printf("%s\t%d\t", desc, num_individuals);

			foreach( unowned ObjectiveStatistics os in objectiveStatistics)
			{
				sb.append( os.to_csv() + "\t" );
			}
			return sb.str;
		}
	}
	
	public struct ObjectiveStatistics
	{
		string desc;
		double min;
		double avg;
		double max;
		
		public string to_string()
		{
			return "%s: %.2f %.2f %.2f".printf(desc, min, avg, max);
		}
		
		public string to_csv()
		{
			return "%s\t%.2f\t%.2f\t%.2f".printf(desc, min, avg, max);
		}
	}
	
	public struct ParetoFrontStatistics
	{
		ObjectiveStatistics[] front;
	}
}
