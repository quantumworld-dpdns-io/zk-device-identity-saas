'use client'

import { useState } from 'react'
import { useSession, signOut } from 'next-auth/react'
import { Menu, Bell, User, LogOut, Settings } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuItem, DropdownMenuSeparator } from '@/components/ui/dropdown-menu'
import Link from 'next/link'

interface TopbarProps {
  onMenuClick: () => void
}

export function Topbar({ onMenuClick }: TopbarProps) {
  const { data: session } = useSession()
  const [notifications] = useState(3)

  return (
    <header className="sticky top-0 z-30 flex h-16 items-center gap-4 border-b bg-background px-4 lg:px-6">
      <Button variant="ghost" size="icon" className="lg:hidden" onClick={onMenuClick}>
        <Menu className="h-5 w-5" />
      </Button>

      <div className="flex-1" />

      <div className="flex items-center gap-2">
        <Button variant="ghost" size="icon" className="relative">
          <Bell className="h-5 w-5" />
          {notifications > 0 && (
            <span className="absolute -right-1 -top-1 flex h-4 w-4 items-center justify-center rounded-full bg-destructive text-[10px] font-bold text-destructive-foreground">
              {notifications}
            </span>
          )}
        </Button>

        <DropdownMenu>
          <DropdownMenuTrigger>
            <Button variant="ghost" size="icon" className="rounded-full">
              <User className="h-5 w-5" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuTrigger>
            <div className="py-1">
              <div className="px-2 py-1.5">
                <p className="text-sm font-medium">{session?.user?.name || 'User'}</p>
                <p className="text-xs text-muted-foreground">{session?.user?.email}</p>
              </div>
              <DropdownMenuSeparator />
              <DropdownMenuItem>
                <Link href="/dashboard/settings" className="flex items-center gap-2">
                  <Settings className="h-4 w-4" />
                  Settings
                </Link>
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={() => signOut({ callbackUrl: '/' })}>
                <div className="flex items-center gap-2">
                  <LogOut className="h-4 w-4" />
                  Log out
                </div>
              </DropdownMenuItem>
            </div>
          </DropdownMenuTrigger>
        </DropdownMenu>
      </div>
    </header>
  )
}
