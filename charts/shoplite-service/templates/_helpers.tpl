{{- define "svc.name" -}}
{{- default .Release.Name .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "svc.selectorLabels" -}}
app.kubernetes.io/name: {{ include "svc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "svc.labels" -}}
{{ include "svc.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/part-of: shoplite
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{- define "svc.image" -}}
{{- required "image.repository is required" .Values.image.repository -}}:{{- required "image.tag is required (an immutable sha-<commit> tag)" .Values.image.tag -}}
{{- end -}}

{{- define "svc.servicePort" -}}
{{- default .Values.containerPort .Values.service.port -}}
{{- end -}}

{{/* Pod-level security: non-root, default seccomp profile (PSS "restricted"). */}}
{{- define "svc.podSecurityContext" -}}
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{- define "svc.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end -}}

{{- define "svc.env" -}}
{{- range $name, $value := .Values.env }}
- name: {{ $name }}
  value: {{ $value | toString | quote }}
{{- end }}
{{- range $name, $ref := .Values.secretEnv }}
- name: {{ $name }}
  valueFrom:
    secretKeyRef:
      name: {{ $ref.secretName }}
      key: {{ $ref.key }}
{{- end }}
{{- end -}}

{{- define "svc.writableVolumeName" -}}
{{- printf "writable-%s" (. | trimPrefix "/" | replace "/" "-") -}}
{{- end -}}
