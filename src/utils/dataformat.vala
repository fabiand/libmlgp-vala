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


public void write_to_file( string filename, string str )
{
	File f = File.new_for_path( filename );

	try {
		f.replace_contents( str, str.length, "", false, 0, null, null );
	} catch(Error e) {
		debug(@"While writing data to '$filename'.");
		error(e.message);
	}
}

public void append_to_file( string filename, string str )
{
	File f = File.new_for_path( filename );

	try {
		OutputStream os = f.append_to( FileCreateFlags.NONE, null);
		
		os.write(str.data, null);
	} catch(Error e) {
		debug(@"While appending data to '$filename'.");
		error(e.message);
	}
}


public class Row : Object
{
	public float[] fields;

	public int length {
		get { return this.fields.length; }
	}

	public new float get( int idx )
	{
		return this.fields[ idx ];
	}
	
	public new void set( int idx, float v )
	{
		this.fields[idx] = v;
	}

	public Row(int s)
	{
		this.fields = new float[s];
	}

	public Row.with_fields(float[] fields)
	{
		this.fields = fields;
	}

	public Row clone()
	{
		Row r = new Row( this.fields.length );
		for( int i = 0; i < this.fields.length ; i++ ) // FIXME can be subst by to_array
		{
			r[i] = this.fields[i];
		}
		return r;
	}
	
	public Row.from_line( string line )
	{
		string[] fs = Regex.split_simple("[\\s,;]+", line);
		this.fields = new float[ fs.length ];
		
		for( int i = 0 ; i < fs.length ; i++ )
		{
			this.fields[i] = (float) double.parse(fs[i]); 
		}
	}

	public string to_string()
	{
		StringBuilder builder = new StringBuilder();
		foreach( float r in this.fields )
		{
			builder.append( r.to_string() );
			builder.append( "\t" );
		}
		return builder.str;
	}

	public float[] to_array()
	{
		float[] ar = new float[ this.fields.length ];
		for( int i = 0; i < this.fields.length ; i++ )
		{
			ar[i] = this.fields[i];
		}
		return ar;
	}
}


public class Header : Object
{
	public string[] titles;
	
	public Header.from_line (string l)
	{
		this.titles = Regex.split_simple("[\\s,;]+", l.strip());
	}
	
	public Header.with_titles (string[] ts)
	{
		this.titles = ts;
	}
	
	public string to_string()
	{
		StringBuilder builder = new StringBuilder();
		foreach( string r in this.titles )
		{
			builder.append( r + "\t" );
		}
		return builder.str;
	}
}

public class Rows : Object
{
	public Header header;
	public Row[] rows;

	public int length {
		get { return this.rows.length; }
	}

	public new Row get( int idx )
	{
		assert( idx < this.rows.length );
		return this.rows[idx];
	}

	public new void set( int idx, Row v )
	{
		assert( idx < this.rows.length );
		this.rows[idx] = v;
	}

	public Rows( int s = 0 )
	{
		this.rows = new Row[ s ];
	}
	
	public Rows.from_file( string filename ) throws Error
	{
		string[] lines = read_lines( filename );

		this.rows = new Row[ lines.length ];
		
		for( int i = 0 ; i < lines.length ; i++ )
		{
			string line = lines[i].strip ();
			if( line.has_prefix("#") || line.has_prefix("%")) //comment
			{
				if (this.header == null)
				{
					this.header = new Header.from_line (line.replace("#","").replace("%",""));
				}
				//this.rows[i] = new Row(0);
			}
			else
			{
				this.rows[i] = new Row.from_line (line);
			}
		}
	}

	public Rows clone()
	{
		Rows r = new Rows( this.rows.length );
		for( int i = 0 ; i < this.rows.length ; i++ )
		{
			r.rows[i] = this.rows[i].clone();
		}
		return r;
	}

	// just unix lines
	static string[] read_lines( string filename )
	{
		File f = File.new_for_path( filename );
		string content = "";
		try {
    		uint8[] blob;
			f.load_contents(null, out blob, null);
			content = (string) blob;
		} catch(Error e) {
			debug(@"Reading lines from '$filename'.");
			error(e.message);
		}
		string[] lines = Regex.split_simple("\\n", content);
		int i = 0;
		foreach( string l in lines ) i++;
		lines.length = i;
		return lines;
	}

	public string to_string( bool with_field_length = true)
	{
		StringBuilder builder = new StringBuilder();
		if (this.header != null) builder.append (this.header.to_string() + "\n");
		foreach( Row r in this.rows )
		{
			builder.append_printf("%s", r.to_string());
			if( with_field_length )
			{
				builder.append_printf(" (%d)", r.length );
			}
			builder.append_printf("\n");
		}
		return builder.str;
	}

	public void to_file(string filename)
	{
		write_to_file( filename, this.to_string(false).replace(",",".") );
	}
}


public class Table : Rows
{

	public int number_of_columns {
		get { return this.rows.length == 0 ? 0 : this.rows[0].length; }
	}

	public Table(int s = 0)
	{
		base(s);
	}

	public Table.from_csv( string filename ) throws Error
	{
		base.from_file( filename );
		clean();
	}

	public new Table clone()
	{
		return (Table) base.clone ();
	}

	void clean()
	{
		if( rows.length == 0 ) return;

		Row[] clean = new Row[0];
		
		int expected_length = -1;// = rows[0].length;
		
		foreach( Row r in this.rows )
		{
			if (r == null) continue;
			if (expected_length < 0)
			{
				expected_length = r.length;
			}
			if( r.length == expected_length )
			{
				clean += r;
			}
			else
			{
				debug("Length of row is wrong.");
			}
		}

		this.rows = clean;
	}

	public float[] get_column(int n)
	{
		float[] col = new float[ this.rows.length ];
		for( int i = 0 ; i < this.rows.length ; i++ )
		{
			col[i] = this.rows[i][n];
		}
		return col;
	}
	
	public void set_column(int n, float[] vs)
	{
		assert (this.rows.length == vs.length);
		for( int i = 0 ; i < vs.length ; i++ )
		{
			this.rows[i][n] = vs[i];
		}
	}

	public void append_row( Row r )
	{
		Row[] rs = new Row[ this.rows.length + 1 ];
		for( int j = 0 ; j < rs.length ; j++ )
		{
			rs[j] = this.rows[j];
		}
		rs[ rs.length -1 ] = r;
		
		this.rows = rs;
	}

	public void append_columns( int n )
	{
		for(int i = 0 ; i < this.rows.length ; i++ )
		{
			Row row = this.rows[ i ];
			float[] nfields = new float[ row.length + n ];
			
			int j = 0;
			for( ; j < row.length ; j++ )
			{
				nfields[ j ] = row[ j ];
			}
			for( ; j < row.length + n ; j++ )
			{
				nfields[ j ] = 0f;
			}
			row.fields = nfields;
		}
	}
	
	public Table subset (int[] ids)
	{
		Table t = new Table (ids.length);
		for (int i = 0 ; i < ids.length ; i++)
		{
			t[i] = this[ids[i]];
		}
		return t;
	}
}


public void random_split (ref Table data, out Table dtrain, out Table dtest, int S)
requires( S > 0 )
requires( S < data.length )
requires( data.length > 1 )
{
	int[] ids = new int[ data.length ];
	for(int i = 0 ; i < ids.length ; i++)
	{
		ids[i] = i;
		debug("...%d", i);
	}
	
	// Vermischen
	Posix.qsort (ids, ids.length, sizeof(int), (a,b) => {
		return Random.boolean () ? -1 : 1;
	});
	debug("shuffled");
	int[] train_ids = ids[0:S],
	      test_ids = ids[S:data.length];
	debug("sliced %d: %d/%d", ids.length, train_ids.length, test_ids.length);
	dtrain = data.subset (train_ids);
	dtest = data.subset (test_ids);
		debug("sliced %d: %d/%d", data.length, dtrain.length, dtest.length);
	assert (dtrain.length + dtest.length == data.length);
}

public void random_split2 (ref Table data, out Table dtrain, out Table dtest, int S)
requires( S > 0 )
requires( S < data.length )
requires( data.length > 1 )
{
	debug ("linsli");
	int[] train_ids = new int[0],
	      test_ids = new int[0];
	for(int i = 0 ; i < data.length ; i++)
	{
		if (Random.next_double()*data.length < S)
		{
			train_ids += i;
		}
		else
		{
			test_ids += i;
		}
	}
	
	debug("sliced %d: %d/%d", data.length, train_ids.length, test_ids.length);
	dtrain = data.subset (train_ids);
	dtest = data.subset (test_ids);
		debug("sliced %d: %d/%d", data.length, dtrain.length, dtest.length);
	assert (dtrain.length + dtest.length == data.length);
}



public void bootstrap (ref Table data, out Table dtrain, out Table dtest, int S = 0)
{
	S = (S == 0 ? data.length : S);
	
	dtrain = new Table (S);
	
	dtrain.header = data.header;
	for (int i = 0 ; i < S ; i++)
	{
		int ridx = Random.int_range (0, data.length-1);
		dtrain[i] = data[ridx];
	}
	
	dtest = data;
	
	for (int i = 0 ; i < data.length ; i++)
	{
		assert (dtrain[i] != null);
		assert (dtest[i] != null);
	}
}



public class ResampleFactory
{

	delegate void SamplingMethod (ref Table data, out Table dtrain, out Table dtest, int S = 0);

	public static void build (string m, int N, ref Table data, ref Table[] training, ref Table[] test)
	{
		SamplingMethod sampling_delegate = null;
		
		if (m == "bootstrap")
		{
				sampling_delegate = bootstrap;
		}
		else
		{
			critical ("Unknown resampling method: '%s'", m);
		}
		
		debug ("Using bootstrap method '%s' with %d samples.", m, N);
		
		training = new Table[ N ];
		test = new Table[ N ];
		
		for (int i = 0 ; i < N ; i++)
		{
			sampling_delegate (ref data, out training[i], out test[i]);
		}
	}

}

