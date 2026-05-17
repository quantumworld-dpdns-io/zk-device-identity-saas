'use client'

import Link from 'next/link'
import { Shield, Cpu, BarChart3, Fingerprint } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'

const features = [
  {
    icon: Shield,
    title: 'ZK Proofs',
    description: 'Generate and verify zero-knowledge proofs for device identity attestation.',
  },
  {
    icon: Cpu,
    title: 'Device Management',
    description: 'Register, monitor, and manage IoT devices with Matter-compliant certificates.',
  },
  {
    icon: BarChart3,
    title: 'Compliance & Analytics',
    description: 'Track attestation trends, detect anomalies, and export compliance data.',
  },
  {
    icon: Fingerprint,
    title: 'Secure Identity',
    description: 'Multi-level certificate chains (DAC/PAI/PAA) with tamper-proof hardware binding.',
  },
]

export default function LandingPage() {
  return (
    <div className="flex min-h-screen flex-col">
      <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="container flex h-16 items-center justify-between">
          <div className="flex items-center gap-2">
            <Shield className="h-6 w-6 text-primary" />
            <span className="text-xl font-bold">ZK Device Identity</span>
          </div>
          <nav className="flex items-center gap-4">
            <Link href="/login">
              <Button variant="ghost">Log in</Button>
            </Link>
            <Link href="/register">
              <Button>Get Started</Button>
            </Link>
          </nav>
        </div>
      </header>

      <section className="relative overflow-hidden py-24 lg:py-32">
        <div className="absolute inset-0 bg-gradient-to-br from-primary/5 via-primary/10 to-background" />
        <div className="absolute top-0 left-1/4 h-96 w-96 rounded-full bg-primary/20 blur-3xl" />
        <div className="absolute bottom-0 right-1/4 h-96 w-96 rounded-full bg-blue-500/10 blur-3xl" />
        <div className="container relative">
          <div className="mx-auto max-w-3xl text-center">
            <h1 className="text-4xl font-bold tracking-tight sm:text-5xl lg:text-6xl">
              Zero-Knowledge Device Identity for IoT
            </h1>
            <p className="mt-6 text-lg text-muted-foreground">
              Manage device attestations, generate ZK proofs, and ensure Matter compliance
              with our enterprise-grade identity platform.
            </p>
            <div className="mt-10 flex items-center justify-center gap-4">
              <Link href="/register">
                <Button size="lg" className="h-12 px-8 text-base">
                  Start Free Trial
                </Button>
              </Link>
              <Link href="/login">
                <Button size="lg" variant="outline" className="h-12 px-8 text-base">
                  Sign In
                </Button>
              </Link>
            </div>
          </div>
        </div>
      </section>

      <section className="container py-16 lg:py-24">
        <div className="mx-auto max-w-5xl">
          <h2 className="text-center text-3xl font-bold tracking-tight">
            Everything you need for device identity
          </h2>
          <p className="mt-4 text-center text-muted-foreground">
            A comprehensive platform for IoT manufacturers
          </p>
          <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
            {features.map((feature) => {
              const Icon = feature.icon
              return (
                <Card key={feature.title} className="border-2 transition-colors hover:border-primary/50">
                  <CardHeader>
                    <Icon className="h-10 w-10 text-primary" />
                    <CardTitle className="mt-4">{feature.title}</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <CardDescription className="text-sm">{feature.description}</CardDescription>
                  </CardContent>
                </Card>
              )
            })}
          </div>
        </div>
      </section>

      <section className="border-t bg-muted/50 py-16">
        <div className="container text-center">
          <h2 className="text-2xl font-bold tracking-tight">Ready to secure your devices?</h2>
          <p className="mt-2 text-muted-foreground">
            Join leading IoT manufacturers using ZK Device Identity.
          </p>
          <Link href="/register">
            <Button size="lg" className="mt-8 h-12 px-8 text-base">
              Get Started Now
            </Button>
          </Link>
        </div>
      </section>

      <footer className="border-t py-8">
        <div className="container flex flex-col items-center justify-between gap-4 md:flex-row">
          <div className="flex items-center gap-2">
            <Shield className="h-5 w-5 text-primary" />
            <span className="text-sm font-medium">ZK Device Identity</span>
          </div>
          <p className="text-sm text-muted-foreground">
            &copy; {new Date().getFullYear()} ZK Device Identity. All rights reserved.
          </p>
        </div>
      </footer>
    </div>
  )
}
