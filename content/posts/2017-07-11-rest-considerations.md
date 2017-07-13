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

In this writing we're going to consider APIs with following properties as RESful:

- HTTP for transport, 
- well-structured noun-based URL (such as /category/123/item/456)
- full range of HTTP methods (at least PUT and DELETE besides GET and POST)
- HTTP codes for error reporting 
- HTTP headers for metadata


I've started to question usefulness of such APIs when taking a new look at DDD and CQRS and questioning how such systems can 
expose their functionality. DDD/CQRS encourage thinking of domain events first and designing rich set of verbs 
(https://cqrs.files.wordpress.com/2010/11/cqrs_documents.pdf, https://lostechies.com/gabrielschenker/2015/04/16/ddd-revisited/). 
This keeps program language closer to business language, captures the intent of the operation rather than implementation details,
simplifies validation. But this event-driven, action-oriented approach is quite the opposite of data-driven API approach we described before -
the set of verbs in RESTful APIs is pre-defined, all the operations are performed by modifying the data in certain locations with POST, PUT and DELETE.
Can this conflict be resolved? Is it possible to expose rich domain model via RESTful APIs without hypermedia? 
ThoughtWorks describes [such attempt](https://www.thoughtworks.com/insights/blog/rest-api-design-resource-modeling) - they call it ["REST without PUT"](https://www.thoughtworks.com/radar/techniques/rest-without-put), however it retains very little even from our simplified understanding of REST and 
in reality degenerates to RPC-style, effectively sacrificing REST in favor of DDD/CQRS, 
immediately triggering angry comments - "How could you do this? It's RPC!". 
Reasoning on DDD/CQRS side is quite practical, while reasoning on REST side is usually cargo-cult style, ending with ultimate argument "if it's RPC-style - it's bad". 

Some authors suggest that (RESTful API approaches do more harm)[https://mmikowski.github.io/the_lie/] than benefit and should be abandoned in favor of so-called ("JSON-Pure")[https://mmikowski.github.io/json-pure/] approach - transport-independent messaging which delivers metadata using application-specific envelope. Somewhat resembles SOAP web-services, but much more lightweight. That seems to be the most extreme step aside from REST - no dependency on any HTTP features, no URLs, everything conveyed in request/response body. It deliberately eliminates all the traits of RESTful API we've described before.  
Were those traits actually useful? If I switch to such JSON-Pure approach, will I miss them? Will I gain something? Let's see what matters in practice.

<table class="doc">
  <thead><th style="width: 50%">For REST</th><th>For RPC</th></thead>
  <tbody>
    <tr>
      <td colspan="2">Essential features</td>
    </tr>
    <tr>
      <td>
        <ul>
          <li>4xx vs 2xx codes enable HTTP clients to distinguish successful/failed Futures/Promises/Deferreds without manual intervention</li>
          <li>With HTTP code 401 UI can distinguish situations when user must log in, therefore quite generic code can handle this situation
          and even re-try failed operation automatically after successful login</li>
          <li>Can specify security credentials in headers and then safely log request body without leaking sensitive information</li>
          <li>When exploring some unfamiliar API I may be sure that GET requests don’t break anything</li>
          <li>Nested API: common re-usable modules may be placed under different parent locations. For example, user management API with urls like /user/1 may be placed under multi-tenancy wrapper and build up URLs like /org/1/user/1</li>
        </ul>
      </td>
      <td>
        <ul>
          <li>Better represents domain operations - can define a message for each domain event, no need to fit interaction into standard HTTP verbs</li>
          <li>Easier to reference multiple objects - no need to invent URLs for something like /items/10,11,12</li>
          <li>No need to decide where some parameter should go - query, body, headers, etc: easier encoding. Like in The Zen of Python - there should be one obvious way to do the job</li>
        </ul>
      </td>
    </tr>
    <tr>
      <td colspan="2">Nice to have, but not crucial</td>
      <tr>
        <td>
          <ul>
            <li>Metadata separate from request (status codes, headers) makes it possible to take some decisions on the content without parsing req/resp body => higher performance</li>
            <li>Easier to work with static JSON serialization libraries (such as Play JSON) - whenever receiving request to specific URL, you usually know exactly what data type to expect</li>
            <li>Support from API documentation tools such as Swagger - ability to pair request and response formats, unlike plain JSON schema which may be used for defining messages in RPC-style communication but doesn’t connect input and output data types</li>
          </ul>
        </td>
        <td>
          <ul>
            <li>Technology-agnostic - can send the same message via AMQP, Thrift, WebSockets, even plain TCP - whatever. To some extend it’s quite useful and can simplify migration of the service to new communication protocol, however it has limitations as not all technologies are born equal. E.g. in HTTP you can get response, with AMQP it’s not so easy, with Kafka - impossible out of the box</li>
            <li>Works uniformly for complex queries: REST usually uses GET for queries, but most tools don’t support body for GET request (though, Elasticsearch still uses GET with body) which makes it necessary sometimes to use POST for just retrieving the data</li>
          </ul>
        </td>
      </tr>
    </tr>
  </tbody>
</table>

Not sure which side wins more from following considerations:

- Authorization - having URLs defined for each resource it’s easier to build non-invasive role-based security - e.g. “manager” can modify “order” entities, while “tech support” can only view them. On the other hand, this kind of security gets pretty limiting very soon as you’d like “customer” to be able to view only his/her own “order” entities, and “manager” to be able to modify orders of their region and not from others. This kind of details will need insight into request body and easier to implement with message passing as you’ll only need to look at the one place (body) instead of two (body and URL). Therefore, REST is easier to start with but hard to go far.

And here are the points which sometimes referred as advantages of RESTful API, which I find not really significant in practice:

- Ability to cache or pre-fetch GET requests based on safety property - caching is really important for the content such as pictures, videos, large texts, program code etc but is rarely desired for the API calls which are typically small and change their result frequently.
On the other hand, ability to re-try GET requests is essential only for early prototyping phase - later on, safety can be defined on per-message base.
- Safely re-trying PUT and DELETE request based on idempotence property - theoretically, this could have been used to improve availability of some
service by using a proxy which captures requests and calls the service when it's available, but this wouldn't work for POST requests and 
therefore can't provide good availability guarantees. Availability needs are better met by explictly using messaging brokers.
Re-trying in practice usually still needs domain knowlege and HTTP method properties don't help too much with it.
- “Natural”, “Human-understandable” or “Easy to remember” structure of the API - you still largely need documentation to know what body to send and what body to expect, and by nicely designing message structure you still can make it understandable enough in order to debug with CLI tools like curl
- bookmarking/history - I’m yet to see the case where someone wants to bookmark an API call. And if you’d like to repeat manually some call that your browser has made then Chrome toolbox can generate curl command for you

Conclusions: TODO
