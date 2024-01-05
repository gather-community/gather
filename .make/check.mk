helm-lint:
	@for dir in ${CHARTS_DIR}/*; do \
		if [ -f "$${dir}/Chart.yaml" ]; then \
			helm lint $${dir}; \
		else \
			echo "No Chart.yaml in $${dir}"; \
		fi \
	done

kubeconfig-local:
	@context=$$(kubectl config current-context); \
	if [ "$${context}" != "docker-desktop" ] && [ "$${context}" != "minikube" ]; then \
		echo "error: Context $$context is not a known LOCAL kube context"; \
		exit 1; \
	fi

depcheck:
	@if ! which kubectl > /dev/null ; then \
		echo "error: Must have kubectl installed and in your PATH" ; \
		exit 1 ; \
	fi
	@if ! which helm > /dev/null ; then \
		echo "error: Must have helm installed and in your PATH" ; \
		exit 1 ; \
	fi