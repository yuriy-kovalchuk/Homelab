```
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```


# **🌟 Steps to Use Cloudflare for Cert-Manager DNS-01 Validation**
This setup allows Cert-Manager to request **TLS certificates** for private subdomains via Cloudflare's DNS.

---

## **1️⃣ Create a Cloudflare API Token**
You need a Cloudflare API token to allow Cert-Manager to manage DNS records for validation.

### **Create API Token:**
1. Go to **[Cloudflare Dashboard](https://dash.cloudflare.com/)**.
2. Navigate to **My Profile > API Tokens**.
3. Click **Create Token**.
4. Select **Create Custom Token** and set these permissions:
   - **Zone > DNS > Edit**
   - **Zone > Zone > Read**
5. Select the zone (your domain) to restrict permissions.
6. Click **Continue to Summary**, then **Create Token**.
7. Copy the token and save it somewhere safe.

---

## **2️⃣ Store the Cloudflare API Token in Kubernetes**
Save the API token as a Kubernetes **secret** so Cert-Manager can use it.

```sh
kubectl create secret generic cloudflare-api-token-secret \
  --namespace cert-manager \
  --from-literal=api-token=YOUR_CLOUDFLARE_API_TOKEN
```

---

## **3️⃣ Create a ClusterIssuer for Cloudflare (DNS-01)**
Create a **ClusterIssuer** that tells Cert-Manager to use **Cloudflare DNS** for validation.

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns
spec:
  acme:
    email: your-email@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-dns-key
    solvers:
    - dns01:
        cloudflare:
          email: your-email@example.com
          apiTokenSecretRef:
            name: cloudflare-api-token-secret
            key: api-token
```

Apply the issuer:
```sh
kubectl apply -f cluster-issuer.yaml
```

---

Yes! Cert-Manager can automatically create certificates for new Ingress resources if properly configured. You can achieve this by adding a **default ClusterIssuer** and modifying your Ingress to request certificates automatically.

---

### **✅ Enable Automatic Certificate Creation**
To make sure every new Ingress automatically gets a TLS certificate:

### **1️⃣ Set a Default ClusterIssuer**
Modify the **Cert-Manager ClusterIssuer** annotation so it applies to all Ingress resources:

```yaml
kubectl annotate ingress --all cert-manager.io/cluster-issuer=letsencrypt-dns
```

OR modify your Ingress class to automatically apply the `ClusterIssuer`:

```yaml
kubectl patch ingressclass nginx -p '{"metadata":{"annotations":{"cert-manager.io/cluster-issuer":"letsencrypt-dns"}}}'
```

---

### **2️⃣ Update Ingress to Automatically Request Certificates**
Modify your Ingress definitions by **removing the secretName** (Cert-Manager will create it):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: private-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-dns  # Automatically request certificate
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - private.example.com
  rules:
    - host: private.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

💡 **No need to manually create certificates!**
Cert-Manager will detect the Ingress, request a new certificate, and store it as a Kubernetes secret.

---

### **3️⃣ Verify Automatic Certificate Creation**
Once the Ingress is applied, Cert-Manager will create a certificate automatically.

Check the status:
```sh
kubectl get certificate -A
```

Describe the certificate request:
```sh
kubectl describe certificate private-tls-cert -n default
```

---

### **🎉 Now, Any New Ingress Will Automatically Get a TLS Certificate!**
- No need to manually create `Certificate` resources.
- Cert-Manager will handle **certificate requests, storage, and renewals**.
- Works for **all new Ingress resources** in your cluster.

Would you like to set up **alerts** for failed certificate requests? 🚀