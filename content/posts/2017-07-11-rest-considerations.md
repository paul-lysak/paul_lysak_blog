+++
date = "2017-07-11T15:56:05+03:00"
draft = true
title = "Are RESTful APIs over-valued?"

+++

Nowdays RESTful APIs are usually considered to be the only reasonable way for communication between 
back-end and front-and, and default approach for communicating between separate back-end services.
Lot of people consider RPC (remote procedure call) as a curse word.
"It's not RESTful", "This is RPC" is often used as an ultimate reason why certain API should be discarded, and another designed instead.  
I used that grounding quite a bit as well, but such reasoning has a cargo cult smell. Let's think a bit about more practical consequences
of following or not following RESTful practices and see where they help, and where not.

I must clarify that we're going to talk about typical understanding of RESTful APIs, 
not initial ideas of Roy Fielding according to which [hyperlinks are mandatory for REST](http://roy.gbiv.com/untangled/2008/rest-apis-must-be-hypertext-driven), a.k.a. HATEOAS (hypermedia as the engine of application state).
I've seen some HATEOAS beleivers, but I'm yet to see a project which would benefit from it. 
Hypermedia works well for human-facing systems, such as web sites, but APIs interact with machines, 
and machines need to be programmed to understand the links, therefore benefits will be quite limited, 
and communication will be much more verbose. Therefore, we're going to leave HATEOAS alone.

In this writing we're going to consider following APIs as RESful:

- uses HTTP for transport, 
- has well-structured noun-based URL (such as /category/123/item/456)
- uses full range of HTTP methods (at least PUT and DELETE besides GET and POST)
- uses HTTP codes for error reporting 
- uses HTTP headers for metadata



