/**
 * Exception for Choob plugin not found errors.
 * @author bucko
 */

package uk.co.uwcs.choob.support;

public final class ChoobNoSuchPluginException extends ChoobNoSuchCallException
{
	public ChoobNoSuchPluginException(String plugin)
	{
		super(plugin);
	}

	public ChoobNoSuchPluginException(String plugin, String call)
	{
		super(plugin, call);
	}
}
