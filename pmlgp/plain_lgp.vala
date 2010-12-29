/* vim: set ts=4 tw=4: */


using VirtualMachine;
using GeneticProgramming;
using LinearGeneticProgramming;

using UI;



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
			const_values[ci] = (float) csplit[1].to_double ();
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


void start_ui (ref unowned string[] args)
{
	
	AppUI ui = new AppUI( ref args );
	sw = ui.sw;

	sw.on_run_toggled.connect( (active) => {
		if( active )
		{
			runner = Thread.create<void*> (run_lgp, true);
		}
		else
		{
			if( sr != null ) sr.stop();
		}
	});

	sw.on_exit.connect( () => {
		sr.stop();
	});

	sw.on_load_data.connect( (filename) => {
		debug( "Loaded file %s", filename );
		_dataFilename = filename;
	});
	
	ressum.on_best_per_complexity_summarized.connect ((candidate_informations, candidate_changed, candidates_objectives) => {
		{
			debug("ui upd");
			int c = 0;
			Individual[] vs = pre_vips; //new Individual[0];
			unowned bool[] forced = sw.forced_entries;
			
			unowned bool[] forced_entries = sw.forced_entries;
			for (int i = 0 ; i < candidate_informations.length ; i++)
			{
				unowned FitnessEvaluationInformation info = candidate_informations[i];
				
				if (info != null && info.individual != null)
				if (forced_entries != null && forced_entries[i])
				{
					for (int o=0; o<info.individual.objectives.length;o++)
					{
						info.individual.objectives[o] = 0;
						info.individual.set_data<bool> ("forced", true);
					}
				}
				else 
				{
					bool? f = info.individual.get_data<bool> ("forced");
					if (f != null && f == true) 
					{
						info.individual.objectives = null;
						sr.fitnessEvaluation (info.individual);
						info.individual.set_data<bool?> ("forced", null);
					}
				}
			
				if (forced != null && forced[i])
				{
					if (info.individual != null)
					{
						vs += info.individual.clone();
					}
				}
			
				if (!candidate_changed[i])
				{
					continue;
				}
				c++;
				
				sw.update_status (
					info.individual.objectives[1].to_string(),
					info.individual.objectives[0].to_string() + "\t %.2f".printf(info.dl),
					info.individual.to_function().to_string(),
					info.individual
				);
			}
			sr.vips = vs;
			
			sgnuplot.to_be_plotted = sw.displayed_entries;
			debug("ui upd %d xx %d %d", c, sw.displayed_entries.length, sgnuplot.to_be_plotted.length);
		}
	});
	
	sw.on_selection_changed.connect ( () => {
		unowned Individual i = sw.currently_selected_entry as Individual;
		if (i==null || i.objectives==null) return;
		
		int complx = (int) 	i.objectives[1];
		
		float[] dtrain = sr.trainAllEvaluation(i),
		        dtest = sr.testAllEvaluation(i);
		float dtt_ratio = dtrain[ObjectiveType.MSE] / dtest[ObjectiveType.MSE];
		
		sw.set_text (
			"Komplexität: %d\nFehler: %.4f\nKomplexität: %.0f\n\nFormel:\n%s\n\n%s\n\nMSE Ratio: %.4f\n\nTrain summary:\n%s\nTest summary:\n%s\n"
			.printf(
				complx,
				i.objectives[0],
				i.objectives[1],
				i.to_function(),
				sgnuplot.get_function_for(complx),
				dtt_ratio,
				ObjectiveType.summarize (dtrain),
				ObjectiveType.summarize (dtest)
			)
		);
	});
	
	sw.on_plot_residual.connect ( () => {
		unowned Individual i = sw.currently_selected_entry as Individual;
		if (i==null || i.objectives==null) return;
		
		int complx = (int) 	i.objectives[1];
		sgnuplot.plot_ext (complx);
	});

	sw.on_base_changed.connect ( () => {
		// FIXME hier das sw anfragen was gerade ausgewählt ist
		/*unowned Individual orig = sw.get_selected_base() as unowned Individual;

		if (orig == null) return;
		if (orig.to_string() == sr.get_bblock().to_string()) return;
		
		Individual ind = orig.clone ();
		sr.set_bblock (ind);*/
//		debug ("base: %s", ind.to_string());
	});

	ui.run();
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




StatusWindow sw;
unowned Thread<void*> runner;
//string[] args;


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

	if (_use_gui)
	{
		start_ui (ref a);
	}
	else
	{
		runner = Thread.create<void*> (run_lgp, true);
		runner.join();
	}
	
	return 0;
}

