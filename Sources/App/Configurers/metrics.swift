
import Metrics
import Prometheus

func bootstrapMetrics() {
    let prometheus = PrometheusClient()

    MetricsSystem.bootstrap(prometheus)
}