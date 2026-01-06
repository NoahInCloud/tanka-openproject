local lib = import '../../../lib/openproject.libsonnet';

lib {
  config+:: {
    namespace: 'lhw-openproject-prod',
    replicas: 2,
    environment: 'production',
  },
  
  // Export only memcached resources
  deployment: $.memcached.deployment,
  service: $.memcached.service,
}
