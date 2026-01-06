local lib = import '../../../lib/openproject.libsonnet';

lib {
  config+:: {
    namespace: 'lhw-openproject-test',
    replicas: 1,
    environment: 'test',
  },
  
  // Export only memcached resources
  deployment: $.memcached.deployment,
  service: $.memcached.service,
}
