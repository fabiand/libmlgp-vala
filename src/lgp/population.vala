/* vim: set ts=4 tw=4: */

using VirtualMachine;
using GeneticProgramming;
using LinearGeneticProgramming;

namespace LinearGeneticProgramming
{


	public class LgpPopulation : Object
	{
		public LgpSettings settings;
		public IndividualSettings individual_creation_settings;
		
		int _generation;
		public int generation {
			get { return _generation; }
		}
		
		LgpSubPopulation[] demes;
		public int number_of_workers = 2;
		ThreadPool<void*> pool_of_demes;
		StaticRWLock all_demes_finished;
		int nt;
		

		public static ObjectivesFunc objectivesDelegate;
		public static TerminationFunc terminationDelegate;


		Individual[] _front;
		public Individual[] front { 
			get { return _front; }
			set { _front = value; }
		}

		public signal void on_generation_begin( int g );


		double[] times;
		public Individual[] vips;


		public LgpPopulation(LgpSettings s)
		{
			this.settings = s;
			
			this.individual_creation_settings = IndividualSettings() {
				min_length = settings.MinimumProgramLength,
				max_initial_length = settings.MaximumInitialLength,
				max_length = settings.MaximumProgramLength,
				used_ops = settings.InstructionSet,
				no_of_vars = settings.RegisterSet,
				no_of_calcs = settings.CalculationSet,
				no_of_consts = settings.ConstantSet
			};
		}
		
		
		public void run() throws Error
		{
		    debug ("Using settings: %s", this.settings.to_string ());
		    
			debug(@"Creating a population with $(settings.PopulationSize) individuals subdivided in $(settings.NumberOfDemes) demes");
			
			{
				this.demes = new LgpSubPopulation[ settings.NumberOfDemes ];
				this.all_demes_finished = StaticRWLock ();
				this.pool_of_demes = new ThreadPool<void*> (demeWorker, this.number_of_workers, true);
				this.nt = 0;
				debug(@"Using $(this.pool_of_demes.get_max_threads()) $(this.number_of_workers) number of threads for demes.");
			}
			
			for( int i = 0 ; i < demes.length ; i++ )
			{
				demes[ i ] = new LgpSubPopulation( this.settings, this.individual_creation_settings );
				demes[ i ].objectivesDelegate = this.objectivesDelegate;
				demes[ i ].terminationDelegate = this.terminationDelegate;
				demes[ i ].initialize();
			}
				
			int numberOfMigrants = (int) (settings.PopulationSize / settings.NumberOfDemes * settings.MigrationRate);
			if( demes.length == 1 ) numberOfMigrants = 0;
			if( numberOfMigrants == 0 ) warning("No migration.");

			/* Initial evaluation, wir dgebraucht um initial die objectives auszwerten */
			debug("Initial evaluation ...");
			int i = 0;
			foreach( unowned LgpSubPopulation cur in this.demes )
			{
				cur.evaluate();
				cur.select();
				debug("%d of %d", i++, demes.length);
			}
				
			debug("Evolutionary loop ...");
			while( !this.terminationDelegate() )
			{
				this.on_generation_begin( _generation );
				
				for( int n = 0 ; n < demes.length ; n++ )
				{
					unowned LgpSubPopulation cur = demes[ n ],
						                     nxt = demes[ (n+1) % demes.length ];
				
				    Individual[] migrants = null;
    				if( demes.length > 1 && ( settings.MigrationInterval == 0 || (_generation % settings.MigrationInterval == 0)))
    				{
    					migrants = cur.emigrate( numberOfMigrants );
    				}
    				
    				nxt.immigrate( migrants );	
				}
				
				assert (AtomicInt.get(ref this.nt) == 0);
				this.all_demes_finished.writer_unlock ();
				debug ("Starting all demes ...");
				for( int n = 0 ; n < demes.length ; n++ )
				{
					AtomicInt.inc(ref this.nt);
					this.all_demes_finished.reader_lock ();
					unowned LgpSubPopulation cur_deme = demes[n];
					this.pool_of_demes.push (cur_deme);
				}
				debug("Waiting for all demes ...%ld, %d", pool_of_demes.unprocessed(), nt);
				this.all_demes_finished.writer_lock ();
				
				debug("All demes finished ...");
				
				front = demes[0].individuals;
				
				_generation++;
			}
		}

		void demeWorker(void* dp)
		{
			unowned LgpSubPopulation deme = (LgpSubPopulation) dp;
			deme.vips = this.vips;
			deme.evolve ();
			this.all_demes_finished.reader_unlock ();
			AtomicInt.dec_and_test(ref this.nt);
		}


		public Individual[] get_individuals()
		{
			Individual[] inds = new Individual[0];
			foreach (unowned LgpSubPopulation sp in this.demes)
			{
				foreach (unowned Individual ind in sp.individuals)
				{
					inds += ind;
				}
			}
			return inds;
		}
		
		public Individual individual_from_instructions (string[] f)
		{
			Individual i = new Individual.with_program(
				this.individual_creation_settings,
				new Program.try_parse (f)
			);
			return i;
		}

		public void reevaluate_all ()
		{
			debug("Forced evaluation ...");
			int i = 0;
			foreach( unowned LgpSubPopulation cur in this.demes )
			{
				cur.evaluate(true);
				debug("%d of %d", i++, demes.length);
			}
		}

		public LgpStatistics getStatistics()
		{
			LgpStatistics stats = LgpStatistics() {
				desc = "Generation " + this.generation.to_string(),
				num_individuals = 0,
				times = this.times
			};

			int oc = this.demes[0].individuals[0].objectives.length;
			
			ObjectiveStatistics[] os = new ObjectiveStatistics[ oc ]; // FIXME
			for( int i = 0 ; i < os.length ; i++ )
			{
				os[i] = ObjectiveStatistics() { desc=i.to_string(), min=double.MAX, avg=0, max=double.MIN };
			}
			
			foreach( unowned LgpSubPopulation sub in this.demes )
			{
				LgpStatistics substats = sub.getStatistics();
				
				stats.num_individuals += substats.num_individuals;
				
				for( int i = 0 ; i < os.length ; i++ )
				{
					if( substats.objectiveStatistics[i].min < os[i].min ) os[i].min = substats.objectiveStatistics[i].min;
					if( substats.objectiveStatistics[i].max > os[i].max ) os[i].max = substats.objectiveStatistics[i].max;
					os[i].avg += substats.objectiveStatistics[i].avg / this.demes.length;
				}
			}
			
			stats.objectiveStatistics = os;
			
			return stats;
		}
	}
}
