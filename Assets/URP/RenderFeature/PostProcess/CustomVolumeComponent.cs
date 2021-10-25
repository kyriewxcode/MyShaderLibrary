using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// 后处理插入位置
public enum CustomPostProcessInjectionPoint
{
    AfterOpaqueAndSky,
    BeforePostProcess,
    AfterPostProcess
}

[Serializable, VolumeComponentMenu("Addition-Post-processing/DepthMap")]
public abstract class CustomVolumeComponent : VolumeComponent, IPostProcessComponent, IDisposable
{
    /// 在InjectionPoint中的渲染顺序，如果相同则按照名字顺序渲染
    public virtual int OrderInPass => 0;

    /// 插入位置
    public virtual CustomPostProcessInjectionPoint InjectionPoint => CustomPostProcessInjectionPoint.AfterPostProcess;

    /// 初始化，将在RenderPass加入队列时调用
    public abstract void Setup();

    /// 执行渲染
    public abstract void Render(
        CommandBuffer cmd,
        ref RenderingData renderingData,
        RenderTargetIdentifier source,
        RenderTargetIdentifier destination
    );


    #region IPostProcessComponent

    /// 返回当前组件是否处于激活状态
    public abstract bool IsActive();

    public virtual bool IsTileCompatible() => false;

    #endregion


    #region IDisposable

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    /// 释放资源
    public virtual void Dispose(bool disposing)
    {
    }

    #endregion
}