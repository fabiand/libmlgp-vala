/* vim: set ts=4 tw=4: */


MessagePassingServer server;
DBus.Connection connection;
dynamic DBus.Object bus;
List<MessagePassingDelegate> clients;

IMessagePassingServer server_object;
IMessagePassingDelegate deleg;


[DBus (name = "named.fabiand.pigp.MessagePassingDelegate")]
interface IMessagePassingDelegate : Object
{
	public abstract signal void newMessageReceived();
	
	public abstract bool passToNeighbor(string[] msg) throws DBus.Error;
	public abstract string[] getMessage( out int senderid ) throws DBus.Error;
	public abstract void signout() throws DBus.Error;
}


[DBus (name = "named.fabiand.pigp.MessagePassingDelegate")]
class MessagePassingDelegate : Object
{
	MessagePassingServer server;

	public MessagePassingDelegate sender;
	public string[] inbox;

	public MessagePassingDelegate( MessagePassingServer s )
	{
		this.server = s;
	}

	public signal void newMessageReceived();

	public bool passToNeighbor(string[] msg) throws DBus.Error
	{
		int idx = clients.index( this ),
		    no_clients = (int) clients.length(),
		    neighidx = ( idx + 1 ) % no_clients;
		bool is_sent = false;
				
		debug(@"Passing message from client $idx to neigbor $neighidx. #clients: $no_clients");

		MessagePassingDelegate neighbor = clients.nth_data( neighidx );

		lock( neighbor.inbox )
		{
			if( neighbor.inbox == null )
			{
				neighbor.inbox = msg;
				neighbor.sender = this;
				is_sent = true;
			}
		}

		if( is_sent) neighbor.newMessageReceived();
				debug("Done.");
		return is_sent;
	}
	
	public string[] getMessage( out int senderid ) throws DBus.Error
	{
		string[] msgs = null;

		lock( this.inbox )
		{
			senderid = clients.index( this.sender );
			msgs = this.inbox;
			this.inbox = null;
		}

		return msgs;
	}

	public void signout() throws DBus.Error
	{
		clients.remove( this );
	}
}


[DBus (name = "named.fabiand.pigp.MessagePassingServer")]
interface IMessagePassingServer : Object
{
	public abstract string get_path_to_delegate() throws DBus.Error;
}


[DBus (name = "named.fabiand.pigp.MessagePassingServer")]
class MessagePassingServer : Object
{
	public MessagePassingServer()
	{
		clients = new List<MessagePassingDelegate>();
	}

	public string get_path_to_delegate() throws DBus.Error
	{
		MessagePassingDelegate d = new MessagePassingDelegate( this );
		
		clients.append( d );
		
		string p = "/named/fabiand/pigp/delegate/" + clients.index(d).to_string();
		
		debug(@"Created new delegate: '$p'");
		connection.register_object( p, d );
		return p;
	}
}


void sighandler(int sig)
{
	message(@"Signal: $sig");
	if( deleg != null ) 
	{
		deleg.signout();
	}
	Posix.exit(0);
}


public static void main()
{

	Posix.signal(Posix.SIGINT, sighandler);

	MainLoop loop = new MainLoop();
	
	connection =  DBus.Bus.get(DBus.BusType.SESSION);
	bus = connection.get_object ("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus");
	uint request_name_result = bus.request_name ("named.fabiand.pigp.TestService", (uint) 0);
	
	if (request_name_result == DBus.RequestNameReply.PRIMARY_OWNER)
	{
		message("Initializing server ...");

		server = new MessagePassingServer();
		connection.register_object( "/named/fabiand/pigp/test" , server );
		
		message("Registered server");
	}
	else
	{
		message("Initializing client ...");
		
		server_object  = (IMessagePassingServer) connection.get_object ( "named.fabiand.pigp.TestService",
					                               "/named/fabiand/pigp/test",
					                               "named.fabiand.pigp.MessagePassingServer");
		
		string p = server_object.get_path_to_delegate();

		deleg = (IMessagePassingDelegate)  connection.get_object ( "named.fabiand.pigp.TestService",
					                               p,
					                               "named.fabiand.pigp.MessagePassingDelegate");

		deleg.newMessageReceived.connect((source) => {
			int sid = -1;
			string[] msg = deleg.getMessage( out sid);
			debug(@"msg received from $sid");
			debug(msg[0]);
			Thread.usleep( (int) (5000000 * Random.next_double()) );
			debug("passing ...");
			bool is_sent = deleg.passToNeighbor( msg );
			debug(@"Sent? $is_sent");
		});

		debug("Sent? %s", deleg.passToNeighbor( new string[]{ "a", "b", "c" } ) ? "y" : "n");

		message("...");
	}
	
	loop.run();
}
