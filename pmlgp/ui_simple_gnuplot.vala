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
using LinearGeneticProgramming;
using Plotting;


public class SimpleGnuplotPresentation : Object
{
	ResultSummarizer connected_summarizer;

	string sesspath;
	
	Posix.FILE gplot;
	
	Individual[] has_been_written;
	Graph g;
	
	int best_complx;
	
	bool first;
	int n = 0;
	
	public bool[] to_be_plotted;
	
	public SimpleGnuplotPresentation(string sp)
	{
		this.sesspath = sp;
		
		debug("Post init...");
		gplot = Posix.FILE.popen("gnuplot -persist", "w");
//		gplot = Posix.FILE.popen("gnuplot", "w");
	//	gplot = Posix.FILE.open("graphs.gnuplot", "w");
		assert( gplot != null );
		
		best_complx = -1;
	}
	
	public void connect_to( ResultSummarizer rs )
	{
		this.connected_summarizer = rs;
		
		this.connected_summarizer.on_best_per_complexity_summarized.connect (this.create_files_and_draw);
	}

	void create_files_and_draw (FitnessEvaluationInformation?[] candidates, bool[] candidate_changed, Table candidates_objectives)
	{
		write_candidates_to_file (candidates, candidate_changed, candidates_objectives);
//		write_best_to_file (candidates, candidate_changed, candidates_objectives);
		gnuplot_candidates_objectives ();
		
		append_statistics_to_history ();
//		append_histogram_to_file (); // für heatmap
	}
	
	
	void append_statistics_to_history ()
	{
	// gnuplot> plot "/tmp/gp/stats.csv" using 8 title "sse", "" using 18 title "complx", "" using 26 title "strlen"
		LgpStatistics stats = this.connected_summarizer.connected_regression.getStatistics ();
		append_to_file( Path.build_filename(sesspath, "stats.csv"), stats.to_csv() + "\n");
		
		foreach (unowned Individual individual in this.connected_summarizer.connected_regression.get_candidates())
		{
			if (individual == null ) continue;
			
			append_to_file( Path.build_filename(sesspath, "scatter-%06d.csv".printf(n)), 
				"%f %f\n".printf(
				individual.objectives[0],
				individual.objectives[1]
				)
			);
		}
	}
	
	public void write_candidates_to_file( FitnessEvaluationInformation[] candidates, bool[] candidate_changed, Table candidates_objectives)
	{
		debug("To file ...");
		
		g = new Graph();
		g.filename = Path.build_filename(sesspath, "%06d.svg".printf(++n));
		g.title = n.to_string ();
		
		if( has_been_written == null ) 
		{
			debug("Nothing yet written - initial write ...");
			has_been_written = new Individual[ candidates.length ];
			for( int j = 0 ; j < has_been_written.length ; j++ )
			{
				has_been_written[j] = null;
			}
		}
		
		first = true;
		for( int cidx = 0  ; cidx < candidates.length ; cidx++ )
		{
			bool changed = candidate_changed[cidx];
			unowned FitnessEvaluationInformation info = candidates[cidx];
						
			if (changed == true)
			{
				write_data_and_func(info);
				
				candidate_changed[cidx] = false;
			}
			
			if (has_been_written[cidx] != null &&
				(to_be_plotted != null && to_be_plotted.length <= candidates.length && to_be_plotted[cidx] == true)
			   )
			{
				add_candidate_to_graph(ref g, ref first, ref cidx);
			}
		}
	}
	
	void write_data_and_func(FitnessEvaluationInformation info)
	{
		unowned Individual i = info.individual;
		int complx = (int) i.objectives[1];
		
		Table train_results = new Table(0);
		for (int ridx = 0 ; ridx < info.expected.length ; ridx++)
		{
			train_results.append_row (new Row.with_fields ({
				info.expected[ridx], 
				info.evaluated[ridx]
			}));
		}
		
		unowned SymbolicRegression sr = connected_summarizer.connected_regression;
		Table test_results = new Table(0);
		float[] info_test = sr.evaluate (i, sr.test_data, 0);
		for (int ridx = 0 ; ridx < info_test.length ; ridx++)
		{
			test_results.append_row (new Row.with_fields ({
				sr.test_data[ridx][0], 
				info_test[ridx]
			}));
		}
		
		
		string funcstr = i.to_function(alias);
		
		train_results.to_file( Path.build_filename(sesspath, @"oh.best.$(complx)") );
		test_results.to_file( Path.build_filename(sesspath, @"oh.best.$(complx).test") );
		write_to_file( Path.build_filename(sesspath, @"oh.best.$(complx).func"), funcstr );
		write_to_file( Path.build_filename(sesspath, @"oh.best.$(complx).info"), 
			"Epoche: %.0f\n\n Fehler: %.4f\nKomplexität: %.0f\n\nFormel:\n%s\n\nTrain summary:\n%s\nTest summary:\n%s\n"
			.printf(
			    this.connected_summarizer.connected_regression.epoche,
				i.objectives[0],
				i.objectives[1],
				i.to_function(sr.test_data.header.titles),
				ObjectiveType.summarize (sr.trainAllEvaluation(i)),
				ObjectiveType.summarize (sr.testAllEvaluation(i))
			)
		);
		
		has_been_written[ complx ] = i;
	}
	
	public string get_function_for (int complx)
	{
		string cont, t;
		size_t l;
		try
		{
			File f = File.new_for_path (Path.build_filename(sesspath, @"oh.best.$(complx).func"));
			uint8[] blob;
			f.load_contents (null, out blob, out t);
			cont = (string) blob;
		}
		catch(Error e)
		{
			cont = e.message;
		}
		return cont;
	}
	
	void add_candidate_to_graph(ref Graph rg, ref bool first, ref int cidx)
	{
		if( first == true )
		{
			Points m = new Points();
			m.filename = Path.build_filename(sesspath, @"oh.best.$(cidx)");
			m.title = "ORIG";
			m.using = "1";
			m.size = 2;
			first = false;
			rg.add( m );
		}

		string funcstr = has_been_written[cidx].to_function();
		
		Line m = new Line();
		m.filename = Path.build_filename(sesspath, @"oh.best.$(cidx)");
		m.title = "%d (%.2f/%ld)".printf(cidx, has_been_written[cidx].objectives[0],funcstr.length);
		m.width = 2;
		m.using = "2";

		rg.add( m );
	}
	
	void gnuplot_candidates_objectives ()
	{
//		debug("Printing graph or not ..");
		GnuplotWriter gw = new GnuplotWriter();
		
		if (false)
		{
			SvgTerminal s = new SvgTerminal();
			s.filename = g.filename;
			gw.terminal = s;
		}
		else
		{
			WxtTerminal w = new WxtTerminal();
			gw.terminal = w;
		}
		
		string gpcmd = gw.build_from( g );
		
//		print( gpcmd );
		
		assert( gplot != null );
		gplot.printf( gpcmd );
		gplot.flush();
	}
	
	
	
	public void plot_ext (int complx)
	{
		Graph gr = new Graph();
		gr.filename = Path.build_filename(sesspath, "%06d.svg".printf(n));

		bool t = true;
		add_candidate_to_graph (ref gr, ref t, ref complx);

		GnuplotWriter gw = new GnuplotWriter();
		gw.terminal = new WxtTerminal();
		
		string gpcmd = gw.build_from( gr );
		
		gplot.printf( gpcmd );
		gplot.flush();
	}
}
