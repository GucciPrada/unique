package com.nesolabs.FingerprintServer.logging;

import java.net.UnknownHostException;
import java.util.Arrays;
import java.util.Calendar;
import java.util.Map;

import net.sourceforge.prowl.api.DefaultProwlEvent;
import net.sourceforge.prowl.api.ProwlClient;
import net.sourceforge.prowl.api.ProwlEvent;
import net.sourceforge.prowl.exception.ProwlException;

import org.apache.log4j.AppenderSkeleton;
import org.apache.log4j.Level;
import org.apache.log4j.MDC;
import org.apache.log4j.PatternLayout;
import org.apache.log4j.spi.LoggingEvent;

import com.mongodb.BasicDBList;
import com.mongodb.BasicDBObject;
import com.mongodb.DB;
import com.mongodb.Mongo;
import com.mongodb.WriteConcern;

public class MongoAppender extends AppenderSkeleton {

	public static final String LEVEL = "level";
	public static final String NAME = "name";
	public static final String APP_ID = "applicationId";
	public static final String TIMESTAMP = "timestamp";
	public static final String PROPERTIES = "properties";
	public static final String TRACEBACK = "traceback";
	public static final String MESSAGE = "message";
	public static final String YEAR = "year";
	public static final String MONTH = "month";
	public static final String DAY = "day";
	public static final String HOUR = "hour";

	protected String host = "localhost";
	protected int port = 27017;
	protected String username;
	protected String password;
	protected String database = "logs";
	protected String collectionPattern = "%c";
	protected PatternLayout collectionLayout = new PatternLayout(collectionPattern);
	protected String applicationId = System.getProperty("APPLICATION_ID", null);
	protected WriteConcern warnOrHigherWriteConcern = WriteConcern.SAFE;
	protected WriteConcern infoOrLowerWriteConcern = WriteConcern.NORMAL;
	protected Mongo mongo;
	protected DB db;

	public MongoAppender() {
	}

	public MongoAppender(boolean isActive) {
		super(isActive);
	}

	public String getHost() {
		return host;
	}

	public void setHost(String host) {
		this.host = host;
	}

	public int getPort() {
		return port;
	}

	public void setPort(int port) {
		this.port = port;
	}

	public String getUsername() {
		return username;
	}

	public void setUsername(String username) {
		this.username = username;
	}

	public String getPassword() {
		return password;
	}

	public void setPassword(String password) {
		this.password = password;
	}

	public String getDatabase() {
		return database;
	}

	public void setDatabase(String database) {
		this.database = database;
	}

	public String getCollectionPattern() {
		return collectionPattern;
	}

	public void setCollectionPattern(String collectionPattern) {
		this.collectionPattern = collectionPattern;
		this.collectionLayout = new PatternLayout(collectionPattern);
	}

	public String getApplicationId() {
		return applicationId;
	}

	public void setApplicationId(String applicationId) {
		this.applicationId = applicationId;
	}

	public void setWarnOrHigherWriteConcern(String wc) {
		this.warnOrHigherWriteConcern = WriteConcern.valueOf(wc);
	}

	public String getWarnOrHigherWriteConcern() {
		return warnOrHigherWriteConcern.toString();
	}

	public String getInfoOrLowerWriteConcern() {
		return infoOrLowerWriteConcern.toString();
	}

	public void setInfoOrLowerWriteConcern(String wc) {
		this.infoOrLowerWriteConcern = WriteConcern.valueOf(wc);
	}

	protected void connectToMongo() throws UnknownHostException {
		this.mongo = new Mongo(host, port);
		this.db = mongo.getDB(database);
	}

	/*
	 * (non-Javadoc)
	 * @see org.apache.log4j.AppenderSkeleton#append(org.apache.log4j.spi.LoggingEvent)
	 */
	@Override
	@SuppressWarnings({ "unchecked" })
	protected void append(final LoggingEvent event) {
		if (null == db) {
			try {
				connectToMongo();
			} catch (UnknownHostException e) {
				throw new RuntimeException(e.getMessage(), e);
			}
		}

		BasicDBObject dbo = new BasicDBObject();
		if (null != applicationId) {
			dbo.put(APP_ID, applicationId);
			MDC.put(APP_ID, applicationId);
		}
		dbo.put(NAME, event.getLogger().getName());
		dbo.put(LEVEL, event.getLevel().toString());
		dbo.put("Location", event.getLocationInformation().getClassName() + "." + event.getLocationInformation().getMethodName() + ": #" + event.getLocationInformation().getLineNumber());
		Calendar tstamp = Calendar.getInstance();
		tstamp.setTimeInMillis(event.getTimeStamp());
		dbo.put(TIMESTAMP, tstamp.getTime());

		// Copy properties into document
		Map<Object, Object> props = event.getProperties();
		if (null != props && props.size() > 0) {
			BasicDBObject propsDbo = new BasicDBObject();
			for (Map.Entry<Object, Object> entry : props.entrySet()) {
				propsDbo.put(entry.getKey().toString(), entry.getValue().toString());
			}
			dbo.put(PROPERTIES, propsDbo);
		}

		// Copy traceback info (if there is any) into the document
		String[] traceback = event.getThrowableStrRep();
		if (null != traceback && traceback.length > 0) {
			BasicDBList tbDbo = new BasicDBList();
			tbDbo.addAll(Arrays.asList(traceback));
			dbo.put(TRACEBACK, tbDbo);
		}

		// Put the rendered message into the document
		dbo.put(MESSAGE, event.getRenderedMessage());

		// Insert the document
		Calendar now = Calendar.getInstance();
		MDC.put(YEAR, now.get(Calendar.YEAR));
		MDC.put(MONTH, String.format("%1$02d", now.get(Calendar.MONTH) + 1));
		MDC.put(DAY, String.format("%1$02d", now.get(Calendar.DAY_OF_MONTH)));
		MDC.put(HOUR, String.format("%1$02d", now.get(Calendar.HOUR_OF_DAY)));

		String coll = event.getLevel().toString();

		MDC.remove(YEAR);
		MDC.remove(MONTH);
		MDC.remove(DAY);
		MDC.remove(HOUR);
		if (null != applicationId) {
			MDC.remove(APP_ID);
		}

		WriteConcern wc;
		if (event.getLevel().isGreaterOrEqual(Level.WARN)) {
			wc = warnOrHigherWriteConcern;
		} else {
			wc = infoOrLowerWriteConcern;
		}
		
		this.db.authenticate(this.username, this.password.toCharArray());
		this.db.getCollection(coll).insert(dbo, wc);
		
		// Send event via Prowl, too
		int level = 0;
		String message = "";
		if (event.getLevel().toString().equals("ERROR")) {
			level = 2;
			message = "\n" + event.getLocationInformation().getClassName() + "." + event.getLocationInformation().getMethodName() + ": #" + event.getLocationInformation().getLineNumber();
		}
		
		ProwlClient client = new ProwlClient();
		ProwlEvent e = new DefaultProwlEvent(
				"<APKIKEY>", "FingerprintServer", event.getLevel().toString() + " (mongoDB)",
				event.getMessage() + message, level);
		try {
			client.pushEvent(e);
		} catch (ProwlException e1) {
			e1.printStackTrace();
		}
	}

	/*
	 * (non-Javadoc)
	 * @see org.apache.log4j.AppenderSkeleton#close()
	 */
	public void close() {

		if (mongo != null) {
			mongo.close();
		}
	}

	/*
	 * (non-Javadoc)
	 * @see org.apache.log4j.AppenderSkeleton#requiresLayout()
	 */
	public boolean requiresLayout() {
		return true;
	}

}
