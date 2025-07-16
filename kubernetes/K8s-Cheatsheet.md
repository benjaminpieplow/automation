# Persistent Volume wrangling
When deleting a persistent volume, they often get stuck as there are dependencies. Ideally these dependencies are deleted with the volumes, but sometimes, they need to learn to fare on their own.

```
kubectl patch pvc {PVC_NAME} -p '{"metadata":{"finalizers":null}}'
```