---
layout: post
name: A RavenDb Extension Method To Get All Documents
date: 2013-06-26
isPost: true
teaser: An extension method for getting all documents from a RavenDb without changing the configuration
---
<a href="https://gist.github.com/ADThomsen/5840375" class="btn btn-inverse" target="_blank">Gist with the code from this post</a>

Getting all documents of a type in RavenDb can be tricky. [RavenDb is Safe By Default](http://ravendb.net/docs/intro/safe-by-default) which means that by default only 128 documents are fetched from the document store if you don't specify a number yourself. That would be done by using the ```.Take()``` method. But even then the maximum number of results is limited to 1024.

The RavenDb documentation referenced above states that <quote>"As a rule of thumb, whenever you are trying to get more than 128 documents in one go, definitely more than 1,024, you are doing something wrong".</quote> That might be a valid point when talking about how much data you should fetch and feed to a user on a web page in one go. But there are also cases where you might indeed need to fetch all your documents without "doing something wrong".

Our case is that we do some integration work at night where we need to update all the documents based on external data. We found that the task was easiest to do if we could load all documents of a type in one go. After a quick Google search [this StackOverflow post](http://stackoverflow.com/questions/10048943/proper-way-to-retrieve-more-than-128-documents-with-ravendb) came up. Taking another look at the Safe By Default documentation it states that the accepted solution on the SO question is a possibility.

OK, so now we can change the configuration to return more documents. But what should we set it to then? 5000? Then how about when we get to 5001 documents? And how do we know which number to specify in the ```.Take()```? Do we just use ```int.MaxValue```? I didn't like this approach so I wrote an extension method to do the work. I based it on the [RavenDb paging documentation](http://ravendb.net/docs/client-api/querying/paging). It looks like this.
``` cs
public static List<T> GetAll<T>(this IDocumentSession session)
{
	const int size = 1024;
	int page = 0;

	RavenQueryStatistics stats;
	List<T> objects = session.Query<T>()
						  .Statistics(out stats)
						  .Skip(page * size)
						  .Take(size)
						  .ToList();

	page++;

	while ((page * size) <= stats.TotalResults)
	{
		objects.AddRange(session.Query<T>()
					 .Skip(page * size)
					 .Take(size)
					 .ToList());
		page++;
	}

	return objects;
}
```

This worked out great and for the amount of documents we had it also performed well. However it soon became insufficient. Next thing you know we need to get all documents of a type based on an expression. Unfortunately this time we couldn't make use of ```RavenQueryStatistics``` because it always returns the count of all documents in the database and not just the ones that fit the expression. So I wrote another extension.
```
public static List<T> GetAll<T>(this IDocumentSession session, Expression<Func<T, bool>> expression)
{
	// We cant use RavenQueryStatistics here since it always returns total number of documents in database
	// not just the ones that fit our expression
	int size = 1024;
	int page = 0;

	List<T> objects = session.Query<T>()
						  .Where(expression)
						  .Skip(page * size)
						  .Take(size)
						  .ToList();

	size = objects.Count;
	page++;

	while (size >= 1024)
	{
		var result = session.Query<T>()
							.Where(expression)
							.Skip(page * size)
							.Take(size)
							.ToList();

		objects.AddRange(result);
		size = result.Count;
		page++;
	}

	return objects;
}
```
Now we had what we needed.

And to wrap it all up in an extension class:

``` cs
public static class DocumentSessionExtensions
{
	public static List<T> GetAll<T>(this IDocumentSession session)
	{
		const int size = 1024;
		int page = 0;

		RavenQueryStatistics stats;
		List<T> objects = session.Query<T>()
							  .Statistics(out stats)
							  .Skip(page * size)
							  .Take(size)
							  .ToList();

		page++;

		while ((page * size) <= stats.TotalResults)
		{
			objects.AddRange(session.Query<T>()
						 .Skip(page * size)
						 .Take(size)
						 .ToList());
			page++;
		}

		return objects;
	}

	public static List<T> GetAll<T>(this IDocumentSession session, Expression<Func<T, bool>> expression)
	{
		// We cant use RavenQueryStatistics here since it always returns total number of documents in database
		// not just the ones that fit our expression
		int size = 1024;
		int page = 0;

		List<T> objects = session.Query<T>()
							  .Where(expression)
							  .Skip(page * size)
							  .Take(size)
							  .ToList();

		size = objects.Count;
		page++;

		while (size >= 1024)
		{
			var result = session.Query<T>()
								.Where(expression)
								.Skip(page * size)
								.Take(size)
								.ToList();

			objects.AddRange(result);
			size = result.Count;
			page++;
		}

		return objects;
	}
}
```

Any and all comments are appreciated - good or bad. As long as they are constructive.

<a href="https://gist.github.com/ADThomsen/5840375" class="btn btn-inverse" target="_blank">Gist with the code from this post</a>