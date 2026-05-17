'use client'

import * as React from 'react'
import { cn } from '@/lib/utils'

interface DialogContextType {
  open: boolean
  onOpenChange: (open: boolean) => void
}

const DialogContext = React.createContext<DialogContextType>({
  open: false,
  onOpenChange: () => {},
})

export function Dialog({
  open: controlledOpen,
  onOpenChange: controlledOnOpenChange,
  children,
}: {
  open?: boolean
  onOpenChange?: (open: boolean) => void
  children: React.ReactNode
}) {
  const [internalOpen, setInternalOpen] = React.useState(false)
  const open = controlledOpen !== undefined ? controlledOpen : internalOpen
  const onOpenChange = controlledOnOpenChange || setInternalOpen

  return (
    <DialogContext.Provider value={{ open, onOpenChange }}>
      {children}
      {open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center">
          <div
            className="fixed inset-0 bg-black/50 backdrop-blur-sm"
            onClick={() => onOpenChange(false)}
          />
          <div className="relative z-50 w-full max-w-lg rounded-lg border bg-background p-6 shadow-lg animate-in fade-in-0 zoom-in-95">
            {children}
          </div>
        </div>
      )}
    </DialogContext.Provider>
  )
}

export function DialogTrigger({ children, asChild }: { children: React.ReactNode; asChild?: boolean }) {
  const { onOpenChange } = React.useContext(DialogContext)
  if (asChild && React.isValidElement(children)) {
    return React.cloneElement(children as React.ReactElement, {
      onClick: () => onOpenChange(true),
    })
  }
  return <button onClick={() => onOpenChange(true)}>{children}</button>
}

export function DialogContent({ className, children, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={cn('', className)} {...props}>
      {children}
    </div>
  )
}

export function DialogHeader({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('flex flex-col space-y-1.5 text-center sm:text-left', className)} {...props} />
}

export function DialogTitle({ className, ...props }: React.HTMLAttributes<HTMLHeadingElement>) {
  return <h2 className={cn('text-lg font-semibold leading-none tracking-tight', className)} {...props} />
}

export function DialogDescription({ className, ...props }: React.HTMLAttributes<HTMLParagraphElement>) {
  return <p className={cn('text-sm text-muted-foreground', className)} {...props} />
}

export function DialogFooter({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2', className)} {...props} />
}

export function DialogClose({ children }: { children: React.ReactNode }) {
  const { onOpenChange } = React.useContext(DialogContext)
  if (React.isValidElement(children)) {
    return React.cloneElement(children as React.ReactElement, {
      onClick: () => onOpenChange(false),
    })
  }
  return <button onClick={() => onOpenChange(false)}>{children}</button>
}
