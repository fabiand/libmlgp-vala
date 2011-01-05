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


namespace Logging
{

	public enum LogLevel
	{
		DEBUG	= 19,
		INFO	= 0,
		ERROR	= -19
	}
	
	public struct LogEntry
	{
		TimeVal occurence_at;
		int level;
		string path;
		string msg;
		
		public string to_string()
		{
			return "%2d %s: %s".printf(level, path, msg);
		}
	}
	
	public class Logger : Object
	{
		LogHandler[] handlers;
		public string path { get; set; default = ""; }
		
		bool lutex;
		
		public Logger()
		{
			this.handlers = new LogHandler [0];
		}
		
		public Logger.with_handler (LogHandler h)
		{
			this.add_handler (h);
		}
		
		public void debug(string msg, string? p = null)
		{
			log(msg, p, LogLevel.DEBUG);
		}
		
		public void info(string msg, string? p = null)
		{
			log(msg, p, LogLevel.INFO);
		}
		
		public void error(string msg, string? p = null)
		{
			log(msg, p, LogLevel.ERROR);
		}
		
		void log(string? m, string? p, LogLevel? l)
		{
		/*	TimeVal time = TimeVal();
			time.get_current_time();
		
			p = p == null ? this.path : p;
		
			LogEntry e = LogEntry() {
				occurence_at = time,
				level = l,
				path = p,
				msg = m
			};
		
			foreach(unowned LogHandler h in this.handlers)
			{
				h.handle( e );
			}*/
		}
		
		public void add_handler(LogHandler h)
		{
			this.handlers += h;
		}
	}
	
	public interface LogHandler : Object
	{
		public abstract void handle(LogEntry e);
	}
	
	public class QueuingLogHandler : LogHandler, Object
	{
		Queue<LogEntry?> entries;
		
		public QueuingLogHandler()
		{
			this.entries = new Queue<LogEntry?>();
		}
		
		public void handle(LogEntry e)
		{
			this.push( e );
		}
		
		void push(LogEntry e)
		{
			this.entries.push_tail( e );
		}
	}
	
	public class PrintLogHandler : LogHandler, Object
	{
		public void handle(LogEntry e)
		{
			print( e.to_string() + "\n" );
		}
	}
}
