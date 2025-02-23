export const jsonFetch = async(resource: string, options: {[key: string]: unknown}): Promise<{[key: string]: any} | null> => {
  options.headers = options.headers || {};
  options.headers["Content-Type"] = "application/json";

  const csrfMeta = document.querySelector("[name='csrf-token']");
  if (csrfMeta instanceof HTMLMetaElement) {
    options.headers["X-CSRF-Token"] = csrfMeta.content;
  }

  options.body = JSON.stringify(options.body);
  const response = await fetch(resource, options);
  return response.status === 204 ? Promise.resolve(null) : response.json();
};
