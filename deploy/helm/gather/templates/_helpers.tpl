{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "gather.app.fullname" -}}
  {{- printf "%s-app" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "gather.app.name" -}}
  {{ include "common.names.name" . }}-app
{{- end -}}

{{/*
Create a default fully qualified postgresql name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "gather.postgresql.fullname" -}}
{{- include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" .Values.postgresql "context" $) -}}
{{- end -}}

{{/*
Create a default fully qualified redis name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "gather.redis.fullname" -}}
{{- include "common.names.dependency.fullname" (dict "chartName" "redis" "chartValues" .Values.redis "context" $) -}}
{{- end -}}

{{/*
Create a default fully qualified elasticsearch name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "gather.elasticsearch.fullname" -}}
{{- include "common.names.dependency.fullname" (dict "chartName" "elasticsearch" "chartValues" .Values.postgresql "context" $) -}}
{{- end -}}


{{/*
Selector labels
*/}}
{{- define "gather.app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "common.names.name" . }}-app
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "gather.app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{ default (printf "%s-app" (include "common.names.fullname" .)) .Values.app.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.app.serviceAccount.name }}
{{- end }}
{{- end }}



{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "gather.imagePullSecrets" -}}
{{ include "common.images.pullSecrets" (dict "images" (list .Values.gather.image) "global" .Values.global) }}
{{- end -}}