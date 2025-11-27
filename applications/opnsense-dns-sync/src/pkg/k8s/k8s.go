package k8s

import (
	"context"
	"k8s.io/apimachinery/pkg/runtime"
	"log"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	crlog "sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
	gatewayv1 "sigs.k8s.io/gateway-api/apis/v1beta1"

	"dns-sync/internal/models"
)

import "dns-sync/pkg/opnsense"

// HTTPRouteReconciler Reconciler implements the reconcile logic
type HTTPRouteReconciler struct {
    client.Client
}

func (r *HTTPRouteReconciler) Reconcile(ctx context.Context, req reconcile.Request) (reconcile.Result, error) {
	var route gatewayv1.HTTPRoute
	if err := r.Get(ctx, req.NamespacedName, &route); err != nil {
		// ignore if not found
		return reconcile.Result{}, client.IgnoreNotFound(err)
	}

	routeInfo := models.HttRouteInfo{
		Name:      route.Name,
		Namespace: route.Namespace,
		Hostnames: []string{},
		Ip:        []string{},
	}

	// Copy hostnames
	for _, h := range route.Spec.Hostnames {
		routeInfo.Hostnames = append(routeInfo.Hostnames, string(h))
	}

	// Collect Gateway IPs
	for _, parentRef := range route.Spec.ParentRefs {
		gwNamespace := route.Namespace
		if parentRef.Namespace != nil {
			gwNamespace = string(*parentRef.Namespace)
		}

		var gw gatewayv1.Gateway
		if err := r.Get(ctx, client.ObjectKey{
			Namespace: gwNamespace,
			Name:      string(parentRef.Name),
		}, &gw); err != nil {
			log.Printf("Failed to get Gateway %s/%s: %v\n", gwNamespace, parentRef.Name, err)
			continue
		}

		for _, addr := range gw.Status.Addresses {
			routeInfo.Ip = append(routeInfo.Ip, addr.Value)
		}
	}

	// Print or use routeInfo
	log.Printf("HTTPRouteInfo: %+v\n", routeInfo)


	go func() {
		err := opnsense.SendIngressInfo(routeInfo)
		if err != nil {
			log.Printf("Error: %s", err.Error())
		}
	}()

	return reconcile.Result{}, nil
}

func StartReconcile() {
    scheme := runtime.NewScheme()
    _ = gatewayv1.AddToScheme(scheme)
	crlog.SetLogger(zap.New(zap.UseDevMode(true)))

    mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
        Scheme: scheme,
    })
    if err != nil {
        panic(err)
    }

    reconciler := &HTTPRouteReconciler{
        Client: mgr.GetClient(),
    }

    err = ctrl.NewControllerManagedBy(mgr).
        For(&gatewayv1.HTTPRoute{}).
        Complete(reconciler)
    if err != nil {
        panic(err)
    }

    log.Println("Starting manager and watching HTTPRoutes...")
    if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
        panic(err)
    }
}