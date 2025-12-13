{{/*
Expand the name of the chart.
*/}}
{{- define "wordpress.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "wordpress.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "wordpress.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "wordpress.labels" -}}
helm.sh/chart: {{ include "wordpress.chart" . }}
{{ include "wordpress.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "wordpress.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wordpress.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "wordpress.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "wordpress.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
WordPress image with tag
*/}}
{{- define "wordpress.image" -}}
{{- $tag := default .Chart.AppVersion .Values.image.tag }}
{{- printf "%s:%s" .Values.image.repository $tag }}
{{- end }}

{{/*
Get the effective replica count based on mode
*/}}
{{- define "wordpress.replicaCount" -}}
{{- if eq .Values.mode "standalone" }}
{{- 1 }}
{{- else }}
{{- max 2 (int .Values.replicaCount) }}
{{- end }}
{{- end }}

{{/*
Check if Redis is required (distributed mode)
*/}}
{{- define "wordpress.redisRequired" -}}
{{- if eq .Values.mode "distributed" }}
{{- true }}
{{- else }}
{{- false }}
{{- end }}
{{- end }}

{{/*
Get MySQL host
*/}}
{{- define "wordpress.databaseHost" -}}
{{- if .Values.mysql.enabled }}
{{- printf "%s-mysql" (include "wordpress.fullname" .) }}
{{- else }}
{{- .Values.externalDatabase.host }}
{{- end }}
{{- end }}

{{/*
Get MySQL port
*/}}
{{- define "wordpress.databasePort" -}}
{{- if .Values.mysql.enabled }}
{{- 3306 }}
{{- else }}
{{- .Values.externalDatabase.port | default 3306 }}
{{- end }}
{{- end }}

{{/*
Get MySQL database name
*/}}
{{- define "wordpress.databaseName" -}}
{{- if .Values.mysql.enabled }}
{{- .Values.mysql.auth.database }}
{{- else }}
{{- .Values.externalDatabase.database }}
{{- end }}
{{- end }}

{{/*
Get MySQL username
*/}}
{{- define "wordpress.databaseUser" -}}
{{- if .Values.mysql.enabled }}
{{- .Values.mysql.auth.username }}
{{- else }}
{{- .Values.externalDatabase.user }}
{{- end }}
{{- end }}

{{/*
Get MySQL secret name
*/}}
{{- define "wordpress.databaseSecretName" -}}
{{- if .Values.mysql.enabled }}
{{- printf "%s-mysql" (include "wordpress.fullname" .) }}
{{- else if .Values.externalDatabase.existingSecret }}
{{- .Values.externalDatabase.existingSecret }}
{{- else }}
{{- printf "%s-db-secret" (include "wordpress.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Get MySQL secret key for password
*/}}
{{- define "wordpress.databaseSecretKey" -}}
{{- if .Values.mysql.enabled }}
{{- "mysql-password" }}
{{- else if .Values.externalDatabase.existingSecret }}
{{- .Values.externalDatabase.existingSecretPasswordKey | default "password" }}
{{- else }}
{{- "password" }}
{{- end }}
{{- end }}

{{/*
Get Redis host
*/}}
{{- define "wordpress.redisHost" -}}
{{- if .Values.redis.enabled }}
{{- printf "%s-redis-master" (include "wordpress.fullname" .) }}
{{- else }}
{{- .Values.externalRedis.host }}
{{- end }}
{{- end }}

{{/*
Get Redis port
*/}}
{{- define "wordpress.redisPort" -}}
{{- if .Values.redis.enabled }}
{{- 6379 }}
{{- else }}
{{- .Values.externalRedis.port | default 6379 }}
{{- end }}
{{- end }}

{{/*
Get Redis database for object cache
*/}}
{{- define "wordpress.redisDatabase" -}}
{{- if .Values.redis.enabled }}
{{- 0 }}
{{- else }}
{{- .Values.externalRedis.database | default 0 }}
{{- end }}
{{- end }}

{{/*
Get Redis database for sessions
*/}}
{{- define "wordpress.redisSessionDatabase" -}}
{{- if .Values.redis.enabled }}
{{- 1 }}
{{- else }}
{{- .Values.externalRedis.sessionDatabase | default 1 }}
{{- end }}
{{- end }}

{{/*
Check if Redis has authentication
*/}}
{{- define "wordpress.redisHasAuth" -}}
{{- if .Values.redis.enabled }}
{{- .Values.redis.auth.enabled }}
{{- else }}
{{- not (empty .Values.externalRedis.password) }}
{{- end }}
{{- end }}

{{/*
Get Redis secret name
*/}}
{{- define "wordpress.redisSecretName" -}}
{{- if .Values.redis.enabled }}
{{- printf "%s-redis" (include "wordpress.fullname" .) }}
{{- else if .Values.externalRedis.existingSecret }}
{{- .Values.externalRedis.existingSecret }}
{{- else }}
{{- printf "%s-redis-secret" (include "wordpress.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Get Redis secret key for password
*/}}
{{- define "wordpress.redisSecretKey" -}}
{{- if .Values.redis.enabled }}
{{- "redis-password" }}
{{- else if .Values.externalRedis.existingSecret }}
{{- .Values.externalRedis.existingSecretPasswordKey | default "password" }}
{{- else }}
{{- "password" }}
{{- end }}
{{- end }}

{{/*
Get PVC name for wp-content
*/}}
{{- define "wordpress.pvcName" -}}
{{- if .Values.persistence.existingClaim }}
{{- .Values.persistence.existingClaim }}
{{- else }}
{{- printf "%s-wp-content" (include "wordpress.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Validate configuration
*/}}
{{- define "wordpress.validateConfig" -}}
{{- if and (eq .Values.mode "distributed") (not .Values.redis.enabled) (empty .Values.externalRedis.host) }}
{{- fail "ERROR: Distributed mode requires redis.enabled=true or externalRedis.host to be set" }}
{{- end }}
{{- if and (not .Values.mysql.enabled) (empty .Values.externalDatabase.host) }}
{{- fail "ERROR: MySQL must be enabled or externalDatabase.host must be set" }}
{{- end }}
{{- if and .Values.mysql.enabled (empty .Values.mysql.auth.password) }}
{{- fail "ERROR: mysql.auth.password is required when mysql.enabled=true" }}
{{- end }}
{{- if and .Values.mysql.enabled (empty .Values.mysql.auth.rootPassword) }}
{{- fail "ERROR: mysql.auth.rootPassword is required when mysql.enabled=true" }}
{{- end }}
{{- end }}
