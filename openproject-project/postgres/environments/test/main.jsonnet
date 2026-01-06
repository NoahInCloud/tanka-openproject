local lib = import '../../../lib/openproject.libsonnet';

lib {
  config+:: {
    namespace: 'lhw-openproject-test',
    storage: '1Gi',
    environment: 'test',
  },
  
  statefulset: $.postgres.statefulset,
  service: $.postgres.service,
}
