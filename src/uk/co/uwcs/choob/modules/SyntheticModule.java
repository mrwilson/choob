/*
 * IntervalModule.java
 *
 * Created on August 5, 2005, 11:25 PM
 */

package uk.co.uwcs.choob.modules;

import uk.co.uwcs.choob.support.*;
import uk.co.uwcs.choob.support.events.*;
import uk.co.uwcs.choob.*;

/**
 * Facilitates the synthesis of artificial message events.
 * @author	sadiq
 */
public final class SyntheticModule
{
	private Choob bot;

	/** Creates a new instance of IntervalModule */
	SyntheticModule( Choob bot )
	{
		this.bot = bot;
	}

	/** Queues the message with the bot, as if it had come from IRC. */
	public void doSyntheticMessage( Message mes )
	{
		if( System.getSecurityManager() != null )
		{
			System.getSecurityManager().checkPermission(new ChoobPermission("canCreateEvents"));
		}

		bot.onSyntheticMessage( mes );
	}
}
