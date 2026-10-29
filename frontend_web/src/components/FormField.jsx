// Gunakan id unik dan label yang terlihat pada formulir modul berikutnya.
export default function FormField({ id, label, error, ...props }) {
  return <div className="form-field"><label htmlFor={id}>{label}</label><input id={id} {...props} aria-invalid={Boolean(error)} aria-describedby={error ? `${id}-error` : undefined}/>{error && <small id={`${id}-error`} role="alert">{error}</small>}</div>;
}
