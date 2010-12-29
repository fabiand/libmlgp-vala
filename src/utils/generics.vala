/* vim: set ts=4 tw=4: */

public class AMap<K,V>
{
	GLib.HashTable<K,V> t;
/*	K[] keys;
	V[] values;*/
	
	public AMap()
	{
		this.t = new HashTable<K,V>(null, null);
/*		this.keys = new K[0];
		this.values = new V[0];*/
	}

	public inline V get(K k)
	{
		return this.t.lookup(k);
/*		int j = -1;
		for( int i = 0 ; i < keys.length ; i++ )
		{
			if( keys[i] == k )
			{
				j = i;
			}
		}
		return j == -1 ?
			null :
			values[j];*/
	}

	public inline void set(K k, V v)
	{
		this.t.replace(k, v);
/*		int j = -1;
		for( int i = 0 ; i < keys.length ; i++ )
		{
			if( keys[i] == k )
			{
				j = i;
				values[i] = v;
			}
		}
		if( j== -1 )
		{
			keys += k;
			values += v;
		}*/
	}
}

public class AList<K>
{
	List<K> l;
	
/*	public AList()
	{
		this.l = new GLib.List<K>();
	}	*/
}


public class Stack<V>
{
	Gee.Deque<V> s;

	public int size {
		get { return this.s.size; }
	}

	public Stack ()
	{
		this.s = new Gee.LinkedList<V> ();
	}
	
	public void push (V v)
	{
		this.s.offer_head (v);
	}
	
	public V pop ()
	{
		return this.s.poll_head ();
	}
	
	public V peek ()
	{
		return this.s.peek_head ();
	}
}

