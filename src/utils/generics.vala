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

