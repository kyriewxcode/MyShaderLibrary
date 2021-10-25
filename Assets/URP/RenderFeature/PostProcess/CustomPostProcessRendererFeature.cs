﻿using System.Collections.Generic;
using System.Linq;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>
/// 自定义后处理Renderer Feature
/// </summary>
public class CustomPostProcessRendererFeature : ScriptableRendererFeature
{
    // 不同插入点的render pass
    CustomPostProcessRenderPass afterOpaqueAndSkyPass;
    CustomPostProcessRenderPass beforePostProcessPass;
    CustomPostProcessRenderPass afterPostProcessPass;

    // 所有自定义的VolumeComponent
    List<CustomVolumeComponent> components;

    // 用于after PostProcess的render target
    RenderTargetHandle afterPostProcessTexture;

    // 初始化Feature资源，每当序列化发生时都会调用
    public override void Create()
    {
        // 从VolumeManager获取所有自定义的VolumeComponent
        var stack = VolumeManager.instance.stack;
        components = VolumeManager.instance.baseComponentTypeArray
            .Where(t => t.IsSubclassOf(typeof(CustomVolumeComponent)) && stack.GetComponent(t) != null)
            .Select(t => stack.GetComponent(t) as CustomVolumeComponent)
            .ToList();

        // 初始化不同插入点的render pass
        InitRenderPass();

        // 初始化用于after PostProcess的render target
        afterPostProcessTexture.Init("_AfterPostProcessTexture");
    }

    void InitRenderPass()
    {
        var afterOpaqueAndSkyComponents = components
            .Where(c => c.InjectionPoint == CustomPostProcessInjectionPoint.AfterOpaqueAndSky)
            .OrderBy(c => c.OrderInPass)
            .ToList();
        afterOpaqueAndSkyPass = new CustomPostProcessRenderPass("Custom PostProcess after Opaque and Sky", afterOpaqueAndSkyComponents);
        afterOpaqueAndSkyPass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;

        var beforePostProcessComponents = components
            .Where(c => c.InjectionPoint == CustomPostProcessInjectionPoint.BeforePostProcess)
            .OrderBy(c => c.OrderInPass)
            .ToList();
        beforePostProcessPass = new CustomPostProcessRenderPass("Custom PostProcess before PostProcess", beforePostProcessComponents);
        beforePostProcessPass.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

        var afterPostProcessComponents = components
            .Where(c => c.InjectionPoint == CustomPostProcessInjectionPoint.AfterPostProcess)
            .OrderBy(c => c.OrderInPass)
            .ToList();
        afterPostProcessPass = new CustomPostProcessRenderPass("Custom PostProcess after PostProcess", afterPostProcessComponents);
        // 为了确保输入为_AfterPostProcessTexture，这里插入到AfterRendering而不是AfterRenderingPostProcessing
        afterPostProcessPass.renderPassEvent = RenderPassEvent.AfterRendering;
    }

    // 你可以在这里将一个或多个render pass注入到renderer中。
    // 当为每个摄影机设置一次渲染器时，将调用此方法。
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (renderingData.cameraData.postProcessEnabled)
        {
            // 为每个render pass设置render target
            var source = new RenderTargetHandle(renderer.cameraColorTarget);
            if (afterOpaqueAndSkyPass.CheckComponents())
            {
                afterOpaqueAndSkyPass.Setup(source, source);
                renderer.EnqueuePass(afterOpaqueAndSkyPass);
            }

            if (beforePostProcessPass.CheckComponents())
            {
                beforePostProcessPass.Setup(source, source);
                renderer.EnqueuePass(beforePostProcessPass);
            }

            if (afterPostProcessPass.CheckComponents())
            {
                // 如果下一个Pass是FinalBlit，则输入与输出均为_AfterPostProcessTexture
                source = renderingData.cameraData.resolveFinalTarget ? afterPostProcessTexture : source;
                afterPostProcessPass.Setup(source, source);
                renderer.EnqueuePass(afterPostProcessPass);
            }
        }
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing && components != null)
        {
            foreach (var item in components)
            {
                item.Dispose();
            }
        }
    }
}