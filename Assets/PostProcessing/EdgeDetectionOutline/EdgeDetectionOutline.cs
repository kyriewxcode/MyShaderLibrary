using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("Custom Post-processing/EdgeDetectionOutline")]
public class EdgeDetectionOutline : CustomVolumeComponent
{
    Material material;
    const string shaderName = "Hidden/PostProcess/EdgeDetectionOutline";

    public BoolParameter isActive = new BoolParameter(false);

    public ClampedFloatParameter edgesOnly = new ClampedFloatParameter(1.0f, 0f, 1f);
    public ColorParameter edgeColor = new ColorParameter(new Color(0, 0, 0, 1));
    public ColorParameter backgroundColor = new ColorParameter(new Color(1, 1, 1, 1));
    public FloatParameter sampleDistance = new FloatParameter(1.0f);
    public FloatParameter sensitivityNormals = new FloatParameter(1.0f);
    public FloatParameter sensitivityDepth = new FloatParameter(1.0f);

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

        material.SetFloat("_EdgeOnly", edgesOnly.value);
        material.SetColor("_EdgeColor", edgeColor.value);
        material.SetColor("_BackgroundColor", backgroundColor.value);
        material.SetFloat("_SampleDistance", sampleDistance.value);
        material.SetVector("_Sensitivity", new Vector4(sensitivityNormals.value, sensitivityDepth.value, 0.0f, 0.0f));

        cmd.Blit(source, destination, material);
    }

    public override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        CoreUtils.Destroy(material);
    }
}