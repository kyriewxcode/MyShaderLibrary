using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("Custom Post-processing/Fog")]
public class Fog : CustomVolumeComponent
{
    Material material;
    const string shaderName = "Hidden/PostProcess/Fog";

    public BoolParameter isActive = new BoolParameter(false);
    public override CustomPostProcessInjectionPoint InjectionPoint => CustomPostProcessInjectionPoint.AfterPostProcess;

    public FloatParameter fogDensity = new FloatParameter(1.0f);
    public ColorParameter fogColor = new ColorParameter(Color.white);
    public FloatParameter fogStart = new FloatParameter(0.0f);
    public FloatParameter fogEnd = new FloatParameter(2.0f);

    public override void Setup()
    {
        if (material == null)
            material = CoreUtils.CreateEngineMaterial(shaderName);
    }

    Matrix4x4 GetFrustumCorners()
    {
        var camera = Camera.main;
        var cameraTransform = camera.transform;

        Matrix4x4 frustumCorners = Matrix4x4.identity;

        float fov = camera.fieldOfView;
        float near = camera.nearClipPlane;
        float aspect = camera.aspect;

        float halfHeight = near * Mathf.Tan(fov * 0.5f * Mathf.Deg2Rad);
        Vector3 toRight = cameraTransform.right * halfHeight * aspect;
        Vector3 toTop = cameraTransform.up * halfHeight;

        Vector3 topLeft = cameraTransform.forward * near + toTop - toRight;
        float scale = topLeft.magnitude / near;

        topLeft.Normalize();
        topLeft *= scale;

        Vector3 topRight = cameraTransform.forward * near + toRight + toTop;
        topRight.Normalize();
        topRight *= scale;

        Vector3 bottomLeft = cameraTransform.forward * near - toTop - toRight;
        bottomLeft.Normalize();
        bottomLeft *= scale;

        Vector3 bottomRight = cameraTransform.forward * near + toRight - toTop;
        bottomRight.Normalize();
        bottomRight *= scale;

        frustumCorners.SetRow(0, bottomLeft);
        frustumCorners.SetRow(1, bottomRight);
        frustumCorners.SetRow(2, topRight);
        frustumCorners.SetRow(3, topLeft);

        return frustumCorners;
    }

    public override void Render(CommandBuffer cmd, ref RenderingData renderingData, RenderTargetIdentifier source, RenderTargetIdentifier destination)
    {
        if (material == null)
            return;

        material.SetMatrix("_FrustumCornersRay", GetFrustumCorners());

        material.SetFloat("_FogDensity", fogDensity.value);
        material.SetColor("_FogColor", fogColor.value);
        material.SetFloat("_FogStart", fogStart.value);
        material.SetFloat("_FogEnd", fogEnd.value);

        cmd.Blit(source, destination, material);
    }

    public override bool IsActive()
    {
        return material != null && (bool)isActive;
    }

    public override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        CoreUtils.Destroy(material);
    }
}