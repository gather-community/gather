/*
 * Builds and submits a throwaway form, so a non-GET request (e.g. a DELETE carrying extra params)
 * can be made as an ordinary page navigation. Rails reads the verb from `_method`; the CSRF token is
 * taken from the page's meta tag.
 */
export const submitHiddenForm = (url: string, method: string, fields: Record<string, string>) => {
  const form = document.createElement("form");
  form.method = "post";
  form.action = url;

  const allFields: Record<string, string> = {_method: method, ...fields};
  const csrfMeta = document.querySelector<HTMLMetaElement>("meta[name=\"csrf-token\"]");
  if (csrfMeta) {
    allFields["authenticity_token"] = csrfMeta.content;
  }

  Object.keys(allFields).forEach((name) => {
    const input = document.createElement("input");
    input.type = "hidden";
    input.name = name;
    input.value = allFields[name];
    form.appendChild(input);
  });

  document.body.appendChild(form);
  form.submit();
};
