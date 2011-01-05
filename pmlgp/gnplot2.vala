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




/*
 * Abstract Graph and Marks
 */
namespace Plotting
{
	public abstract class GraphVisitor : Object
	{
		public abstract void visit_graph( Graph g );
		public abstract void visit_mark( Mark m );
	}

	public abstract class GraphElement : Object
	{
		public abstract void accept( GraphVisitor v );
	}

	public class Graph : GraphElement
	{
		public string title { get; set; }
	
		public int width { get; set; }
		public int height { get; set; }

		public string filename { get; set; }
	
		public unowned GLib.List<Mark> marks { get; set; }

		public Graph()
		{
			this.marks = new GLib.List<Mark>();
		}

		public void add( Mark m )
		{
			this.marks.append( m );
		}
	
		public override void accept( GraphVisitor v )
		{
			v.visit_graph( this );
		}
	}

	public enum SmoothType
	{
		None,
		Unique,
		Frequency,
		Cumulative,
		KDensity,
		CSplines,
		ACSplines,
		Bezier,
		SBezier;
	}

	public abstract class Mark : GraphElement
	{
		public string filename { get; set; }
	
		public string using { get; set; }
		public string title { get; set; }
		public SmoothType smooth_type { get; set; default = SmoothType.None; }
	
	
		public override void accept( GraphVisitor v )
		{
			v.visit_mark( this );
		}
	}

	public class Line : Mark
	{
		public int width { get; set; }
		public int style { get; set; }
	}

	public class Points : Mark
	{
		public int size { get; set; }
	}
	
	public class Dots : Mark
	{
		public int size { get; set; }
	}

	public class Boxes : Mark
	{
	}
}




/*
 * Concrete Gnuplot visitor
 */
namespace Plotting
{

	public abstract class Terminal
	{
		public abstract string to_string();
	}
	
	public class X11Terminal : Terminal
	{
		public int xid;
		public override string to_string()
		{
			return @"set terminal x11 window $(this.xid);\n";
		}
	}
	
	public class WxtTerminal : Terminal
	{
		public override string to_string()
		{
			return @"set terminal wxt;\n";
		}
	}
	
	public class PngTerminal : Terminal
	{
		public string filename;
		public override string to_string()
		{
			return @"set terminal png;\nset output \"$(this.filename)\";\n";
		}
	}
	
	public class SvgTerminal : Terminal
	{
		public string filename;
		public override string to_string()
		{//1280,720
			return @"set terminal svg size 1024,576 font \",8\";\nset output \"$(this.filename)\";\n";
		}
	}
	

	public class GnuplotWriter : GraphVisitor
	{
		StringBuilder sb;
	
		bool is_last_mark;
	
		public Terminal terminal { get; set; }

		public GnuplotWriter()
		{
			this.sb = new StringBuilder();
		}
	
		public GnuplotWriter.for_terminal(Terminal t)
		{
			this.terminal = t;
			this.sb = new StringBuilder();
		}
	
		public string build_from( Graph g )
		{
			this.visit_graph( g );
			return sb.str;
		}

		public override void visit_graph( Graph g )
		{
			sb.append("# Written by GnuplotWriter.\n");
//			sb.append_printf("set terminal svg size %d, %d;\n", g.width, g.height);
//			sb.append_printf("set terminal svg size 1024,576 font \",8\";\nset output \"%s\";\n", g.filename);
//			sb.append("set boxwidth 0.9;\nset output \"s\";\n");

			sb.append (this.terminal.to_string());
			
			sb.append_printf ("set key outside left;\n");

			if (g.title != null)
			{
				sb.append_printf ("set title \"%s\";\n", g.title);
			}

			if( g.marks.length() == 0 )
			{
				sb.append("# No marks.");
			}
			else
			{
				sb.append("plot \\\n");		
				is_last_mark = false;
				for( int i = 0 ; i < g.marks.length() ; i++ )
				{
					Mark m = g.marks.nth_data(i);
					if( i == g.marks.length() - 1 ) 
					{
						is_last_mark = true;
					}
					m.accept( this );
				}
			}
		}
	
		public override void visit_mark( Mark m )
		{
			sb.append_printf("\t\"%s\" ", m.filename);
		
			if( m.using != null ) sb.append_printf( "using %s ", m.using );
		
			if( m is Points ) visit_points_mark( m, sb );
			if( m is Dots ) visit_dots_mark( m, sb );
			if( m is Line ) visit_line_mark( m, sb );
			if( m is Boxes ) sb.append( "with boxes " );
		
			if( m.title != "" ) sb.append_printf( "title \"%s\" ", m.title );
			if( m.smooth_type != SmoothType.None ) sb.append_printf( "smooth %s ", m.smooth_type.to_string().split("_")[2].down() );
		
			sb.append( is_last_mark ? ";\n" : ", \\\n" );
		}

		void visit_line_mark( Mark m, StringBuilder sb )
		{
			Line l = m as Line;
			sb.append( "with lines " );
			if( l.width > 0 ) sb.append_printf( "linewidth %d ", l.width );
			if( l.style > 0 ) sb.append_printf( "linestyle %d ", l.style );
		}
		
		void visit_points_mark( Mark m, StringBuilder sb )
		{
			Points p = m as Points;
			sb.append( "with points " );
			if( p.size > 0 ) sb.append_printf( "pointsize %d ", p.size );
		}
		
		void visit_dots_mark( Mark m, StringBuilder sb )
		{
			Dots d = m as Dots;
			sb.append( "with dots " );
			if( d.size > 0 ) sb.append_printf( "linewidth %d ", d.size );
		}
	}
}



