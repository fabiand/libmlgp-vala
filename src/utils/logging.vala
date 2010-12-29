/* vim: set ts=4 tw=4: */

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
