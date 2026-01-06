local lib = import '../../../lib/openproject.libsonnet';

lib {
  config+:: {
    namespace: 'lhw-openproject-test',
    replicas: 1,
    environment: 'test',
  },
  
  deployment: $.openproject.deployment,
  service: $.openproject.service,
}
