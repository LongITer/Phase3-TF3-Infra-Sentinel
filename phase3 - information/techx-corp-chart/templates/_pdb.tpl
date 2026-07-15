{{/*
Demo component PDB template
*/}}
{{- define "techx-corp.pdb" }}
{{- $minReplicas := 1 }}
{{- if .hpa }}
  {{- if .hpa.enabled }}
    {{- $minReplicas = default 1 .hpa.minReplicas }}
  {{- end }}
{{- else }}
  {{- $minReplicas = default .defaultValues.replicas .replicas }}
{{- end }}
{{- if gt (int $minReplicas) 1 }}
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ .name }}
  labels:
    {{- include "techx-corp.labels" . | nindent 4 }}
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      {{- include "techx-corp.selectorLabels" . | nindent 6 }}
{{- end }}
{{- end }}
