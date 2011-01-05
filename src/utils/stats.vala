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



namespace Statistics
{
	static const float MAX_MSE = 1e30f;

	public double adjust (double stdf)
	{
		return 1 / ( 1 + stdf );
	}
	
	public double normalize (double adj, double adj_sum)
	{
		return adj / adj_sum;
	}

	public inline bool contains_nan(float[] fs)
	{
		foreach(unowned float f in fs)
		{
			if( f.is_nan() )
			{
				return true;
			}
		}
		return false;
	}

	public double average_of (float[] values)
	{
		if (contains_nan(values))
		{
			return MAX_MSE;
		}
		
		double avg = 0;
		
		for (int i = 0 ; i < values.length ; i++)
		{
			avg += values[i];
		}

		if (avg > MAX_MSE || avg.is_nan())
		{
			avg = MAX_MSE;
		}
		else
		{
			avg /= values.length;
		}
		
		return avg;
	}

	public double mdl_for (float[] predicted, float[] desired, long sum_ops)
	{
		if (contains_nan(predicted))
		{
			return MAX_MSE;
		}
		
		long m = predicted.length,
		     N = sum_ops;
		
		return 0.5 * m * Math.log (mse_for(predicted, desired)) + 0.5 * N * Math.log (m);
	}

	public double r_square_for (float[] predicted, float[] desired)
	{
		return 1 - ( sse_for (predicted, desired) / sst_for (desired) );
	}
	
	public double sst_for (float[] desired)
	{
		if( contains_nan(desired) )
		{
			return MAX_MSE;
		}
		
		double avg = average_of (desired),
		       sum = 0;
		
		for( int i = 0 ; i < desired.length ; i++ )
		{
			sum += Math.pow((desired[i] - avg), 2);
		}

		if( sum > MAX_MSE || sum.is_nan() )
		{
			sum = MAX_MSE;
		}
		
		return sum;
	}

	/*
	 * Mean absolute error
	 */
	public double mae_for (float[] predicted, float[] desired)
		requires (predicted.length > 0 && predicted.length == desired.length)
	{
		if (contains_nan(predicted))
		{
			return MAX_MSE;
		}
		
		double mae = 0;
		
		for (int i = 0 ; i < predicted.length ; i++)
		{
			mae += Math.fabs (predicted[i] - desired[i]);
		}

		if (mae > MAX_MSE || mae.is_nan())
		{
			mae = MAX_MSE;
		}
		else
		{
			mae = mae / predicted.length;
		}

		return mae;
	}

	/*
	 * Sum of squared errors
	 */
	public double sse_for (float[] predicted, float[] desired, bool use_relative = false)
		requires( predicted.length > 0 && predicted.length == desired.length )
	{
		if( contains_nan(predicted) )
		{
			return MAX_MSE;
		}
		
		double sum = 0;
		
		for( int i = 0 ; i < predicted.length ; i++ )
		{
			if (use_relative)
			{
				double pi = predicted[i],
				       di = desired[i];
				if (desired[i] == 0)
				{
					pi += float.MIN;
					di = float.MIN;
				}
				
				sum += Math.pow((pi - di), 2) / di;
			}
			else
			{
				sum += Math.pow((predicted[i] - desired[i]), 2);
			}
		}

		if( sum > MAX_MSE || sum.is_nan() )
		{
			sum = MAX_MSE;
		}

		return sum;
	}
	
	/*
	 * Mean squared errors
	 */
	public double mse_for (float[] predicted, float[] desired, bool use_relative = false)
	{
		double sse = sse_for (predicted, desired, use_relative);
				
		double mse = sse / predicted.length;

		
		if( mse > MAX_MSE || mse.is_nan() )
		{
			mse = MAX_MSE;
		}
		
		return mse;
	}

	/*
	 * Root mean squared errors
	 */
	public double rmse_for(float[] predicted, float[] desired, bool use_relative = false)
	{
		double rmse = Math.sqrt( mse_for(predicted, desired, use_relative) );

		if( rmse > MAX_MSE || rmse.is_nan() )
		{
			rmse = MAX_MSE;
		}
		
		return rmse;
	}
	
	public double maximum_error_of ( float[] predicted, float[] desired )
		requires( predicted.length > 0 && predicted.length == desired.length )
	{
		if( contains_nan(predicted) )
		{
			return MAX_MSE;
		}
		
		double max = double.MIN;
		
		for( int i = 0 ; i < predicted.length ; i++ )
		{
			double diff = Math.fabs((predicted[i] - desired[i]));
			if( diff > max )
			{
				max = diff;
			}
		}

		if( max > MAX_MSE || max.is_nan() )
		{
			max = MAX_MSE;
		}

		return max;
	}

	public double minimum_error_of ( float[] predicted, float[] desired )
		requires( predicted.length > 0 && predicted.length == desired.length )
	{
		if( contains_nan(predicted) )
		{
			return MAX_MSE;
		}
		
		double min = double.MAX;
		
		for( int i = 0 ; i < predicted.length ; i++ )
		{
			double diff = Math.fabs((predicted[i] - desired[i]));
			if( diff < min )
			{
				min = diff;
			}
		}

		if( min > MAX_MSE || min.is_nan() )
		{
			min = MAX_MSE;
		}

		return min;
	}

	public int number_of_not_matching_parenthese (string s, int maxlen = 1000)
	{
		int sum = 0;
		
		int cur = 0;
		string ep = "()";
		for (long i = 0 ; i<s.length ; i++)
		{
			unowned unichar c = s[i];
			
			if (!ep.contains(c.to_string()))
			{
				continue;
			}
			
			if (c == ep[ cur % ep.length ])
			{
				cur++;
			}
			else
			{
				sum++;
			}
		}
		return sum;
	}
}
