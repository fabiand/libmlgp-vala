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
using LinearGeneticProgramming;



void sighandler(int sig)
{
	debug("Signal received: %d", sig);
	Posix.exit( Posix.EXIT_SUCCESS );
}

Individual[] pre_vips;

void init(ref unowned string[] args)
{
	message("Initializing Symbolic regression");

	settings = create_settings_from_arguments(ref args);
	
	load_or_generate_data();

	vm = new InterpretingVM();
	sr = new SymbolicRegression (settings, _maxGenerations, _numberOfWorkerThreads);
	
	pre_vips = new Individual[0];
	foreach (unowned string __f in __functions)
	{
		Individual i = sr.individual_from_instructions (__f.strip().split ("\n"));
		debug("Adding previp: %s", i.to_string());
		pre_vips += i;
	}
	
	// Summarizes data
	ressum = new ResultSummarizer();
	ressum.summary_size = 150;
	ressum.connect_to ( sr );
}

void load_or_generate_data()
{
	if( _dataFilename == null )
	{
		var prob = ProblemType.ASurface;
		debug ("Using problem %s", prob.to_string());
//		data = data_for_problem(ProblemType.KellerBanzhaf1996, 100);
//		data = data_for_problem(ProblemType.DISTANCE_3, 100);
//		data = data_for_problem(ProblemType.MEXICANHAT, 100);
//		data = data_for_problem(ProblemType.Saito1997, 200);
//		data = data_for_problem(ProblemType.x4x3x2x, 20);
		data = data_for_problem(prob, 200);
	}
	else
	{
		data = new Table.from_csv( _dataFilename );
	}

	/* Definierte Konstanten bnestimmen */
	string[] consts = _constants.split (",");
	string[] const_titles = new string[consts.length];
	float[] const_values = new float[consts.length];
	for (int ci = 0 ; ci < consts.length ; ci++)
	{
		string curc = consts[ci];
		if (/[a-z]+=[0-9.]+/.match(curc))
		{
			string[] csplit = curc.split ("=");
			const_titles[ci] = csplit[0];
			const_values[ci] = (float) double.parse (csplit[1]);
			debug("Using constant '%s' with value '%.4f'.", const_titles[ci], const_values[ci]);
		}
		else
		{
			critical ("Constant not given in format name=value: '%s'", curc);
		}
	}

	int used = data[0].length;
	
	data.append_columns( _numberOfCalculationRegisters + _numberOfConstantRegisters + consts.length );
	alias = new string[ data[0].length ];
	for(int i = 0 ; i < data.length ; i++ )
	{
		int k = used, j = 0;
		Row r = data[i];
		for( ; k < used + _numberOfCalculationRegisters ; k++ )
		{
			r[k] = 1f;
			alias[k] = "1";
		}
		for( ; k < used + _numberOfCalculationRegisters + _numberOfConstantRegisters ; k++ )
		{
			int c = j++;
			r[k] = c;
			alias[k] = c.to_string();
		}
		j = 0;
		for( ; k < used + _numberOfCalculationRegisters + _numberOfConstantRegisters + consts.length ; k++ )
		{
			r[k] = const_values[j];
			alias[k] = const_titles[j];
			j++;
		}
	}
	settings.ConstantSet = _numberOfConstantRegisters + consts.length;
	

	alias[0] = "0"; // NOTE: Erste Spalte ist immer ziel, daher ists null, weils so avor der rechnugn gestetzt wird
	if (data.header != null) debug("Header: %s", data.header.to_string());
	for( int k = 1 ; k < used ; k++ )
	{
		if (data.header == null)
		{
			debug("Creating generic aliases.");
			alias[k] = ((char) ('a' + k)).to_string();
		}
		else
		{
			debug("Header titles provided, using as alias. %s",  data.header.titles[k]);
			alias[k] = data.header.titles[k];
		}
	}

	settings.RegisterSet = used;
}



LgpSettings settings;

VM vm;
SymbolicRegression sr;
ResultSummarizer ressum;
SimpleGnuplotPresentation sgnuplot;

Table data;
string[]? alias = null;

void start_lgp() throws Error
{
	debug ("Starting LGP ...");
	int train_size = (int) (_trainFraction * data.length);
	debug("size %d, trainsize %d", data.length, train_size);
	random_split2 (ref data, out sr.train_data, out sr.test_data, train_size);
	sr.train_data.header = new Header.with_titles (alias);
	sr.test_data.header = new Header.with_titles (alias);
	
	if(_noiseRatio != 0.0)
	{
		debug ("Adding noise: +/- %.4f", _noiseRatio);
		foreach (unowned Row r in data.rows)
		{
			float n = (float) ( 2*_noiseRatio*r[0]* Random.next_double() - _noiseRatio*r[0]);
			r[0] = r[0] + n; 
		}
	}
	
	print("Data:\n" + data.to_string());
	print("Traindata:\n" + sr.train_data.to_string());
	print("Testdata:\n" + sr.test_data.to_string());
	
	
	// Outputs them via gnuplot
	sgnuplot = new SimpleGnuplotPresentation(_sessionPath);
	sgnuplot.connect_to ( ressum );
	
	sr.on_next_candidates.connect( (g) => {
		//if( g % 10 == 0 )
		{
			var stats = sr.getStatistics();
			message(stats.to_string());
			debug("# Individuals %d" , _individual_count);
			/*if (stats.objectiveStatistics[0].min <= _maxFitness)
			{
				debug ("Min fotness reached");
				sr.stop ();
			}*/
		}
	});
	
	sr.run();
}




unowned Thread<void*> runner;



void* run_lgp()
{
	try
	{
		start_lgp();
	}
	catch(Error e)
	{
		critical(e.message);
	}
	return null;
}

int k = 0;

int main(string[] a)
{
	if( !Thread.supported () )
	{
		error ("Cannot run without thread support.");
	}

	init (ref a);

	runner = Thread.create<void*> (run_lgp, true);
	runner.join();
	
	return 0;
}

