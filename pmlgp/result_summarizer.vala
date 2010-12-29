/* vim: set ts=4 tw=4: */

using GeneticProgramming;
using LinearGeneticProgramming;



public class ResultSummarizer : Object
{
	public SymbolicRegression connected_regression;
	
	Individual[] candidates;
	FitnessEvaluationInformation[] candidate_informations;
	bool[] candidate_changed;


	public int summary_size { get; set; }

	public signal void on_best_per_complexity_summarized( FitnessEvaluationInformation[] candidate_informations, bool[] candidate_changed, Table candidates_objectives );
	
		

	public ResultSummarizer()
	{
		this.notify["summary-size"].connect( () => {
			this.candidates = new Individual[ this.summary_size ];
			this.candidate_informations = new FitnessEvaluationInformation[ this.summary_size ];
			this.candidate_changed = new bool[ this.summary_size ];
		});
	}
	
	public void connect_to( SymbolicRegression sr )
	{
		this.connected_regression = sr;
		this.connected_regression.on_next_candidates.connect( this.summarize_generation );
		this.connected_regression.on_reevaluated.connect ( this.all_dirty );
	}


	void summarize_generation( int g )
	{
		Table candidates_objectives = this.create_best_per_complexity_table();
		this.on_best_per_complexity_summarized ( 
			this.candidate_informations, 
			this.candidate_changed, 
			candidates_objectives
			);
	}
	
	void all_dirty()
	{
		debug ("Setting all dirty");
		for (int i = 0 ; i < candidate_changed.length ; i++ )
		{
			this.candidate_changed[i] = true;
		}
	}
	
	Table create_best_per_complexity_table()
	{
		Individual[] cands = this.connected_regression.get_candidates ();
		
		Row[] rs = new Row[ 0 ];
		
		int ni=0;
		for( int kk = 0 ; kk < cands.length ; kk++ )
		{
			unowned Individual cand = cands[kk];
			assert( cand is Individual );
			
			FitnessEvaluationInformation current_info = cand.get_data<FitnessEvaluationInformation>("FitnessEvaluationInformation");
			
			if( current_info == null )
			{
				ni++;
				debug("ind %d is missing info", cand.id);
				continue;
			}
			
//			debug( "best per complx rc %ld", cand.ref_count);
//			debug( "bests len %d", cand.objectives.length );
			
			float errr = cand.objectives[0];
			int complx = (int) cand.objectives[1];
			
//			debug("obs %.4f %d", errr, complx);
			

			if( complx >= this.candidates.length )
			{
				continue; // complx is too high - ignore
			}
			
			
			{
				/* Select data for candidates_objectives / summary */
				Row r = new Row.with_fields(new float[]{
					(float) complx, 
					errr
				});
			
				rs += r;
			}			
			
			if (candidates[complx] == null
			    || !(candidates[complx] is Individual))
			{
				candidates[complx] = cand;
				candidate_informations[complx] = current_info;
				candidate_changed[complx] = true;
			}
			else
			{
				if( errr < candidate_informations[complx].individual.objectives[0] ) 
				{
					candidates[complx] = cand;
					candidate_informations[complx] = current_info;
					candidate_changed[complx] = true;
				}
			}
		}
		if( ni > 0 ) debug("NO INFO %d, INFO %d", ni, cands.length - ni);
		
		Table candidate_objectives = new Table(0);
		candidate_objectives.rows = rs;
		
		return candidate_objectives;
	}
}
