{{- define "homepage.name" -}}
homepage
{{- end }}

{{- define "homepage.fullname" -}}
{{ .Release.Name }}-homepage
{{- end }}

{{- define "homepage.chart" -}}
{{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{- define "homepage.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{ default (printf "%s-%s" .Release.Name "homepage") .Values.serviceAccount.name }}
{{- else }}
{{ .Values.serviceAccount.name }}
{{- end }}
{{- end }}
