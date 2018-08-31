---
title: "Embedding SwaggerUI into http4s projects"
date: 2018-08-31T13:01:00+03:00
tags: ["swagger", "swagger-ui", "http4s"]
years: ["2018"]
---

I'd like to share an approach for integrating SwaggerUI into Scala projects, using http4s as example.
With webjars available you don't need to copy its complete code into your project, 
you'll need just a small piece of it along with 2 dependencies to your `build.sbt` file - 
one with SwaggerUI code, and another - webjar ulitity library:

    libraryDependencies ++= {
      "org.webjars" % "webjars-locator" % "0.34",
      "org.webjars" % "swagger-ui"      % "3.17.3" 
    }

Now we need to customize `index.html` - it hardcodes the URL of the specification, that's not what we want. Copy `index.html` from SwaggerUI code into `src/main/resources/swagger-ui` folder of your project, then change `SwaggerUIBundle` instantiation code to the following:

      const ui = SwaggerUIBundle({
          configUrl: "config.json", //Customization - replaces hardcoded URL
          dom_id: '#swagger-ui',
          deepLinking: true,
          presets: [
              SwaggerUIBundle.presets.apis,
              SwaggerUIStandalonePreset
          ],
          plugins: [
              SwaggerUIBundle.plugins.DownloadUrl
          ],
          layout: "StandaloneLayout"
      })

Now you can define `HttpService` somewhere in your project and use it the same way you use other HTTP services in your `http4s` application:

    private val applicationUrl = "http://some.server.com:8080" //should be configurable to match your deploy
    private val swaggerUiPath = Path("swagger-ui") 

    val service = org.http4s.HttpService[IO] {
      case request @ GET -> `swaggerUiPath` / "config.json" =>
        //Specifies Swagger spec URL
        Ok(Json.obj("url" -> Json.fromString(s"$applicationUrl/swagger.yaml")))
        //Entry point to Swagger UI
      case request @ GET -> `swaggerUiPath` =>
        PermanentRedirect(Location(uri("swagger-ui/index.html")))
      case request @ GET -> path if path.startsWith(swaggerUiPath) =>
        //Serves Swagger UI files
        val file = "/" + path.toList.drop(swaggerUiPath.toList.size).mkString("/")
        (if(file == "/index.html") {
          StaticFile.fromResource("/swagger-ui/index.html", Some(request))
        } else {
          StaticFile.fromResource(swaggerUiResources + file, Some(request))
        }).getOrElseF(NotFound())
    }

    private val swaggerUiResources = s"/META-INF/resources/webjars/swagger-ui/$swaggerUiVersion"

    private lazy val swaggerUiVersion: String = {
      Option(new WebJarAssetLocator().getWebJars.get("swagger-ui")).fold {
        throw new RuntimeException(s"Could not detect swagger-ui webjar version")
      } { version =>
        version
      }
    }

Now you can run your application and open `/swagger-ui` in browser - it will redirect you to `/swagger-ui/index.html` with swagger spec location `<applicationUrl>/swagger.yaml`. If you don't already have Swagger spec exposed there and you have that spec in static YAML file you might want to add another endpoint:

    case request @ GET -> "swagger.yaml" =>
      StaticFile.fromResource("/swagger.yaml", Some(request)).getOrElseF(NotFound())

