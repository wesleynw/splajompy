import Foundation
import OpenTelemetryApi
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk
import ResourceExtension
import URLSessionInstrumentation

/// Initializes Open Telemetry, including the global trace provider and automatic instrumentation for URLSession
func initializeOtel() {
  guard
    let endpoint = URL(string: "https://api.splajompy.com/otel/v1/traces")
  else {
    return
  }

  let spanExporter = OtlpHttpTraceExporter(
    endpoint: endpoint
  )
  let spanProcessor = BatchSpanProcessor(spanExporter: spanExporter)

  let serviceName = "ios-app"
  #if DEBUG
    let environment = "development"
  #else
    let environment = "production"
  #endif

  let resource = Resource(attributes: [
    "service.name": AttributeValue.string(serviceName),
    "service.version": AttributeValue.string(
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        ?? "unknown"
    ),
    "service.instance.id": AttributeValue.string(UUID().uuidString),
    "deployment.environment": AttributeValue.string(environment),
  ])

  OpenTelemetry.registerTracerProvider(
    tracerProvider: TracerProviderBuilder()
      .add(spanProcessor: spanProcessor)
      .with(resource: resource)
      .build()
  )

  let config = URLSessionInstrumentationConfiguration(
    shouldInstrument: { request in
      guard let url = request.url else { return false }
      return !url.path().contains("/otel/")
    },
    nameSpan: { request in
      guard let url = request.url else { return nil }
      let method = request.httpMethod ?? "GET"
      return "\(method) \(url.absoluteString)"
    }
  )

  _ = URLSessionInstrumentation(configuration: config)
}
