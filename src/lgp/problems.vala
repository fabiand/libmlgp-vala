/* vim: set ts=4 tw=4: */

using VirtualMachine;
using GeneticProgramming;

public enum ProblemType
{
	CUSTOM,
	SURFACE_1,
	MEXICANHAT,
	DISTANCE_2,
	DISTANCE_3,
	POLY_4,
	MOP2,
	KellerBanzhaf1996,
	Saito1997,
	x4x3x2x,
	ASurface,
	COUNT
}

public Table data_for_problem(ProblemType t, int s)
{
	debug("Generating data for %s", t.to_string ());
	Table data = new Table(s);
	float[] data_res = new float[ data.length ];
	for(int i = 0 ; i < data.length ; i++ )
	{
		Row r = new Row(10);
	
		switch( t )
		{
			case ProblemType.CUSTOM: // custom
				float x = (float) (8 * Random.next_double() - 4),
					  y = (float) (8 * Random.next_double() - 4);
				r = new Row( 3 );
				r[0] = data_res[i] = (float) Math.pow( 3*( x * y ), 2 );
				r[1] = x;
				r[2] = y;
				break;
				
			case ProblemType.SURFACE_1:
			// http://gnuplot.sourceforge.net/demo/surface1.html
				float x = (float) (2 * Random.next_double()),
					  y = (float) (2 * Random.next_double());
				
				r = new Row( 3 );
				r[0] = data_res[i] = (float) ( Math.pow(x,2)+Math.pow(y,2) * (1+0.5*Random.next_double()));

				r[1] = x;
				r[2] = y;
				break;
				
			case ProblemType.MEXICANHAT:// mexican hat
//				if(i==0) data.header = new Header.from_line ("r x y");
				r = new Row(3);
				float x = (float) (i % 8)-4, //(8 * Random.next_double() - 4),
					  y = (float) (8 * Random.next_double() - 4);
				r[0] = data_res[i] = (float) ( (1-(x*x)/4-(y*y)/4) * (float) Math.exp( -((x*x)/8) -((y*y)/8) ) ); 
				r[1] = x;
				r[2] = y;
				break;

			case ProblemType.DISTANCE_2:
				float x = (float) (8 * Random.next_double() - 4),
					  y = (float) (8 * Random.next_double() - 4);
				      x  = (float) Random.next_double();
					  y  = (float) Random.next_double();
				float x1 = (float) Random.next_double();
				float y1 = (float) Random.next_double();
				r = new Row( 1 + 4 );
				r[0] = Math.sqrtf( Math.powf(x-y,2) + Math.powf(x1-y1,2) );
				r[1] = x;
				r[2] = y;
				r[3] = x1;
				r[4] = y1;
				break;
			

			case ProblemType.DISTANCE_3:
				float x = (float) (8 * Random.next_double() - 4),
					  y = (float) (8 * Random.next_double() - 4);
				      x  = (float) Random.next_double();
					  y  = (float) Random.next_double();
				float x1 = (float) Random.next_double();
				float y1 = (float) Random.next_double();
				float x2 = (float) Random.next_double();
				float y2 = (float) Random.next_double();
				r = new Row( 1 + 6 );
				r[0] = Math.sqrtf( Math.powf(x-y,2) + Math.powf(x1-y1,2) + Math.powf(x2-y2,2) );
				r[1] = x;
				r[2] = y;
				r[3] = x1;
				r[4] = y1;
				r[5] = x2;
				r[6] = y2;
				break;
			
			case ProblemType.POLY_4:
				float x = (float) Random.next_double();
				r = new Row( 2 );
				r[0] = data_res[i] = (float) x*x*x*x + x*x*x + x*x + x;
				r[1] = x;
				break;

			case ProblemType.KellerBanzhaf1996:
				double m = Random.next_double(),
				       v = Random.next_double(),
				       q = Random.next_double(),
				       a = Random.next_double();
				r = new Row( 1 + 4 );
				r[0] = (float) ( Math.sin(m) * Math.cos(v) * (1/Math.sqrt(Math.exp(q))) + Math.tan(a) );
				r[1] = (float) m;
				r[2] = (float) v;
				r[3] = (float) q;
				r[4] = (float) a;
				break;
				
			case ProblemType.Saito1997:
				if(i==0) data.header = new Header.from_line ("y x1 x2 x3 x4 x5 x6 x7 x8 x9");
				r = new Row( 1 + 9 );
				r[1] = (float) Random.next_double();
				r[2] = (float) Random.next_double();
				r[3] = (float) Random.next_double();
				r[4] = (float) Random.next_double();
				r[5] = (float) Random.next_double();
				r[6] = (float) Random.next_double();
				r[7] = (float) Random.next_double();
				r[8] = (float) Random.next_double();
				r[9] = (float) Random.next_double();
				r[0] = (float) ( 2 + 3*r[1]*r[2] + 4*r[3]*r[4]*r[5] );
				break;
				
			case ProblemType.x4x3x2x:
				if(i==0) data.header = new Header.from_line ("y x");
				double x = -1 + 2 * Random.next_double();
				r = new Row( 1 + 1 );
				r[0] = (float) ( x*x*x*x + x*x*x + x*x + x );
				r[1] = (float) x;
				break;
				
			case ProblemType.ASurface:
				if(i==0) data.header = new Header.from_line ("r x y");
				double x = -5 + 10 * Random.next_double(),
				       y = -5 + 10 * Random.next_double();
				r = new Row( 1 + 2 );
				r[0] = (float) (3*Math.pow(x,2)*Math.pow(y,2) + 4*x*Math.pow(y,2) + Math.sin(x*y)*500 - 3*x*y);
				r[1] = (float) x;
				r[2] = (float) y;
				break;
		}
	
		data[i] = r;
	}

	return data;
}

