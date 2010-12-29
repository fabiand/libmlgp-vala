/* vim: set ts=4 tw=4: */


using VirtualMachine;
using GeneticProgramming;
using LinearGeneticProgramming;


string _dataFilename;
string _sessionPath;
int _populationSize;
int _numberOfDemes;
int _maxGenerations;
double _maxFitness;
double _trainFraction;
int _maxSize;
double _probMutation;
double _probCrossover;
double _migrationRate;
int _migrationInterval;
int _tournamentSize;
int _numberOfCalculationRegisters;
int _numberOfConstantRegisters;
string _constants;
string _operators;
string _functions;
bool _use_gui;
double _seed;
bool _withoutComplexityObjective;
int _numberOfWorkerThreads = 2;
double _noiseRatio = 0.025;

static const OptionEntry[] mainOptions = {
	{ "file", 					'f', 0, OptionArg.FILENAME, ref _dataFilename, "Filename providing the data in CSV format.", "FILENAME" },
	{ "session-dir",			'p', 0, OptionArg.FILENAME, ref _sessionPath, "Home of all session related files.", "PATH" },
	{ "gui",				    'u' , 0, OptionArg.NONE, ref _use_gui, "If the GUI shall be displayed for interactive use.", null },
	{ null }
};

static const OptionEntry[] advancedOptions = {
	{ "train-fraction",			 0 , 0, OptionArg.DOUBLE, ref _trainFraction, "", "0.75"},
	{ "population-size", 		's', 0, OptionArg.INT, ref _populationSize, "Number of individuals.", "5000" },
	{ "demes", 					'd', 0, OptionArg.INT, ref _numberOfDemes, "The number of demes.", "100" },
	{ "max-generations", 		'g', 0, OptionArg.INT, ref _maxGenerations, "Maximum number of generations.", "5000" },
/*	{ "min-fitness", 			 0 , 0, OptionArg.DOUBLE, ref _maxFitness, "When this fitness is reached, terminate.", "0.01" },
	{ "max-size", 				 0 , 0, OptionArg.DOUBLE, ref _maxSize, "Maximum size.", "250" },*/
	{ "probability-mutation", 	'm', 0, OptionArg.DOUBLE, ref _probMutation, "Probability for mutation.", "0.9" },
	{ "probability-crossover", 	'c', 0, OptionArg.DOUBLE, ref _probCrossover, "Probability for crossovers.", "0.1" },
	{ "migration-rate",          0 , 0, OptionArg.DOUBLE, ref _migrationRate, "Rate of migrations", "0.05" },
	{ "migration-interval",          0 , 0, OptionArg.INT, ref _migrationInterval, "Number of generations between migrations.", "4" },
	{ "tournament-size",         0 , 0, OptionArg.INT, ref _tournamentSize, "1/2 Size of tournament", "2" },
	{ "num-calcs",				 0 , 0, OptionArg.INT, ref _numberOfCalculationRegisters, "The number of calculation registers.", "3" },
	{ "num-consts",				 0 , 0, OptionArg.INT, ref _numberOfConstantRegisters, "The number of constants.", "10" },
	{ "constants",				 0 , 0, OptionArg.STRING, ref _constants, "Predefined constants.", "" },
	{ "operators",				 0 , 0, OptionArg.STRING, ref _operators, "Comma seperated list of operators to be used (+,-,*,/,^,exp,sin,cos,pow,tan,sqrt,log_e)", "+,-,*,/" },
	{ "functions",				 0 , 0, OptionArg.STRING, ref _functions, "Semicolon separated list of functions, like 'pow ( x , 2 )'.", "" },
	{ "seed",					 0 , 0, OptionArg.DOUBLE, ref _seed, "Salt for random numbers.", "(Zufall/Zeit)" },
	{ "num-workers",             0 , 0, OptionArg.INT, ref _numberOfWorkerThreads, "Number of worker threads used for demes.", "2" },
	{ "without-complexity-objective", 0,0, OptionArg.NONE, ref _withoutComplexityObjective, "If the complexity measure shall be ignore while optimizing.", null },
	{ "noise",                   0 , 0, OptionArg.DOUBLE, ref _noiseRatio, "Noisefacotr (+/-).", "0.025" },
	{ null }
};

string[] __functions;
LgpSettings create_settings_from_arguments(ref unowned string[] args)
{
	assert (args != null);
	
	LgpSettings settings;
	
	OptionContext oc = new OptionContext("- A LGP regression tool.");
	oc.add_main_entries(mainOptions, null);
	
	OptionGroup opts_advanced = new OptionGroup ("advanced", "Advanced symbolic regression options.", "Show advanced options.");
	opts_advanced.add_entries (advancedOptions);
	oc.add_group ((owned) opts_advanced);

	_trainFraction = 0.75;
	_populationSize = _numberOfDemes = _maxGenerations = _maxSize = _numberOfCalculationRegisters = _numberOfConstantRegisters = _tournamentSize = _migrationInterval = -1;
	_maxFitness = _probMutation = _probCrossover = _migrationRate = _seed = -1d;
	_operators = _functions = null;
	_use_gui = false;
	
	try {
		oc.parse(ref args);
	} catch (OptionError? err) {
		assert(err != null && err.message != null);
		critical(err.message);
	}

	Posix.signal(Posix.SIGINT, sighandler);
	
	/*
	 * Defaults.
	 */
//	if( _dataFilename == null )	error("You must provide a data filename using -d or --data.");

	if( _populationSize == -1 ) _populationSize = 5000;
	if( _numberOfDemes == -1 ) _numberOfDemes = 100;
	if( _maxGenerations == -1 )	_maxGenerations = 1000;
	if( _maxFitness == -1 )	_maxFitness = 0.01d;
	if( _maxSize == -1 )	_maxSize = 250;
	if( _probMutation == -1 ) _probMutation = 0.9;
	if( _probCrossover == -1 ) _probCrossover = 0.1;
	if( _migrationRate == -1 ) _migrationRate = 0.05;
	if( _migrationInterval == -1 ) _migrationInterval = 4;
	if( _tournamentSize == -1 ) _tournamentSize = 2;
	if( _numberOfCalculationRegisters == -1 ) _numberOfCalculationRegisters = 3;
	if( _numberOfConstantRegisters == -1 ) _numberOfConstantRegisters = 10;
	if( _constants == null ) _constants = ""; //pi=3.141,e=2.718";
	if( _operators == null ) _operators = "+,-,*,/";
	if( _functions == null ) _functions = "";
	//FIXME if (_seed == 0d )
	{
		_seed = Random.next_double () * Random.next_int ();
	}
	debug("Seed %.10f", _seed);
	Random.set_seed( (uint32) _seed );
//	if( _use_gui == null ) _use_gui = true;
	
	
	settings = SymbolicRegression.get_default_settings();
	
	settings.PopulationSize = _populationSize;
	settings.NumberOfDemes = _numberOfDemes;
	settings.CrossoverProbability = _probCrossover;
	settings.MutationProbability = _probMutation;
	settings.TournamentSize = _tournamentSize;
	settings.MigrationRate = _migrationRate;
	settings.MigrationInterval = _migrationInterval;
	settings.RegisterSet = 0; // Gets filled later, number of vars
	settings.CalculationSet = _numberOfCalculationRegisters;
	settings.ConstantSet = _numberOfConstantRegisters; // changed later because of _constants
	settings.InstructionSet = VirtualMachine.Operation.try_parse_all (_operators.split(","));
	
	if (_withoutComplexityObjective)
	{
		// Nur Fehler (def. SSE)
		debug ("No complexity objective.");
		settings.SelectionObjectives = { settings.SelectionObjectives[0] };
	}
	
	foreach(unowned Operation a in settings.InstructionSet)
	{
		debug("Using operation %s", a.to_string());
	}
	
	__functions = parse_functions ();

	return settings;
}


string[] parse_functions ()
{
	string[] functions = new string[0];
	
	foreach (unowned string func in _functions.split(";"))
	{
		Dijkstra.ShuntingYard y = new Dijkstra.ShuntingYard ();
		
		string postfix = y.transform_infix_to_postfix ((func));
		string p = y.postfix_to_program (postfix);
		debug(p);
		functions += p;
	}
	
	return functions;
}
