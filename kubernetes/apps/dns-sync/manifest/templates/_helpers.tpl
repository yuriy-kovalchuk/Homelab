{{- define "tpl.name" -}}
{{- default (include "chart.name" .) .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tpl.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s" $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "tpl.namespace" -}}
{{- default .Release.Namespace .Values.namespace.name -}}
{{- end -}}

{{- define "tpl.labels" -}}
{{- $root := .root -}}
{{- $extra := default (dict) .extra -}}
{{- $labels := dict "app.kubernetes.io/name" (include "tpl.fullname" $root) "app.kubernetes.io/instance" (include "tpl.fullname" $root) "app.kubernetes.io/managed-by" "Helm" -}}
{{- $merged := merge $labels (default (dict) $root.Values.common.labels) $extra -}}
{{- toYaml $merged -}}
{{- end -}}

{{- define "tpl.annotations" -}}
{{- $root := .root -}}
{{- $extra := default (dict) .extra -}}
{{- $merged := merge (default (dict) $root.Values.common.annotations) $extra -}}
{{- toYaml $merged -}}
{{- end -}}

{{- define "tpl.selectorLabels" -}}
{{- $root := .root -}}
{{- $name := default (include "tpl.fullname" $root) .name -}}
{{- toYaml (dict "app.kubernetes.io/name" $name "app.kubernetes.io/instance" $name) -}}
{{- end -}}
