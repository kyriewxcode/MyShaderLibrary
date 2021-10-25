using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("Custom Post-processing/DepthMap")]
public class DepthMap : CustomVolumeComponent
{
    Material material;
    const string shaderName = "Hidden/PostProcess/DepthMap";

    public BoolParameter isActive = new BoolParameter(false);

    public override CustomPostProcessInjectionPoint InjectionPoint => CustomPostProcessInjectionPoint.AfterPostProcess;

    public override void Setup()
    {
        if (material == null)
            material = CoreUtils.CreateEngineMaterial(shaderName);
    }

    public override bool IsActive()
    {
        return material != null && (bool)isActive;
    }

    public override void Render(
        CommandBuffer cmd,
        ref RenderingData renderingData,
        RenderTargetIdentifier source,
        RenderTargetIdentifier destination)
    {
        if (material == null)
            return;
        
        cmd.Blit(source, destination, material);
    }

    public override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        CoreUtils.Destroy(material);
    }
}