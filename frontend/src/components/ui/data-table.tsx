'use client'

import { useState, useMemo } from 'react'
import { ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight, Search, ArrowUpDown, ArrowUp, ArrowDown } from 'lucide-react'
import { Button } from './button'
import { Input } from './input'
import { Table, TableHeader, TableBody, TableHead, TableRow, TableCell } from './table'
import { cn } from '@/lib/utils'

export interface Column<T> {
  key: string
  header: string
  cell: (item: T) => React.ReactNode
  sortable?: boolean
  filterable?: boolean
}

interface DataTableProps<T> {
  columns: Column<T>[]
  data: T[]
  pageSize?: number
  searchable?: boolean
  searchKeys?: (keyof T)[]
  className?: string
  onRowClick?: (item: T) => void
}

export function DataTable<T extends Record<string, unknown>>({
  columns,
  data,
  pageSize = 10,
  searchable = true,
  searchKeys,
  className,
  onRowClick,
}: DataTableProps<T>) {
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)
  const [sortKey, setSortKey] = useState<string | null>(null)
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc')

  const filtered = useMemo(() => {
    if (!search || !searchKeys) return data
    const lower = search.toLowerCase()
    return data.filter((item) =>
      searchKeys.some((key) => {
        const val = item[key]
        return val != null && String(val).toLowerCase().includes(lower)
      })
    )
  }, [data, search, searchKeys])

  const sorted = useMemo(() => {
    if (!sortKey) return filtered
    return [...filtered].sort((a, b) => {
      const aVal = a[sortKey]
      const bVal = b[sortKey]
      if (aVal == null) return 1
      if (bVal == null) return -1
      const cmp = String(aVal).localeCompare(String(bVal), undefined, { numeric: true })
      return sortDir === 'asc' ? cmp : -cmp
    })
  }, [filtered, sortKey, sortDir])

  const totalPages = Math.max(1, Math.ceil(sorted.length / pageSize))
  const paged = sorted.slice(page * pageSize, (page + 1) * pageSize)

  const handleSort = (key: string) => {
    if (sortKey === key) {
      setSortDir(sortDir === 'asc' ? 'desc' : 'asc')
    } else {
      setSortKey(key)
      setSortDir('asc')
    }
  }

  const SortIcon = ({ columnKey }: { columnKey: string }) => {
    if (sortKey !== columnKey) return <ArrowUpDown className="ml-1 h-3 w-3 inline opacity-40" />
    return sortDir === 'asc'
      ? <ArrowUp className="ml-1 h-3 w-3 inline" />
      : <ArrowDown className="ml-1 h-3 w-3 inline" />
  }

  return (
    <div className={cn('space-y-4', className)}>
      {searchable && searchKeys && (
        <div className="relative max-w-sm">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Search..."
            value={search}
            onChange={(e) => {
              setSearch(e.target.value)
              setPage(0)
            }}
            className="pl-9"
          />
        </div>
      )}
      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              {columns.map((col) => (
                <TableHead
                  key={col.key}
                  className={cn(col.sortable && 'cursor-pointer select-none')}
                  onClick={() => col.sortable && handleSort(col.key)}
                >
                  <span className="flex items-center">
                    {col.header}
                    {col.sortable && <SortIcon columnKey={col.key} />}
                  </span>
                </TableHead>
              ))}
            </TableRow>
          </TableHeader>
          <TableBody>
            {paged.length === 0 ? (
              <TableRow>
                <TableCell colSpan={columns.length} className="h-24 text-center text-muted-foreground">
                  No results found.
                </TableCell>
              </TableRow>
            ) : (
              paged.map((item, i) => (
                <TableRow
                  key={(item.id as string) || i}
                  className={cn(onRowClick && 'cursor-pointer')}
                  onClick={() => onRowClick?.(item)}
                >
                  {columns.map((col) => (
                    <TableCell key={col.key}>{col.cell(item)}</TableCell>
                  ))}
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">
          Page {page + 1} of {totalPages} ({sorted.length} total)
        </p>
        <div className="flex items-center gap-1">
          <Button variant="outline" size="icon" onClick={() => setPage(0)} disabled={page === 0}>
            <ChevronsLeft className="h-4 w-4" />
          </Button>
          <Button variant="outline" size="icon" onClick={() => setPage(page - 1)} disabled={page === 0}>
            <ChevronLeft className="h-4 w-4" />
          </Button>
          <Button variant="outline" size="icon" onClick={() => setPage(page + 1)} disabled={page >= totalPages - 1}>
            <ChevronRight className="h-4 w-4" />
          </Button>
          <Button variant="outline" size="icon" onClick={() => setPage(totalPages - 1)} disabled={page >= totalPages - 1}>
            <ChevronsRight className="h-4 w-4" />
          </Button>
        </div>
      </div>
    </div>
  )
}
