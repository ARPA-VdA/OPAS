import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Checkbox } from "@/components/ui/checkbox"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"

export type FieldKind = 'text' | 'number' | 'boolean' | 'select'

/** Sentinel for a 'select' field's "no value set" option - a Radix SelectItem
 * can't use value="" (reserved internally), so this stands in for `null`. */
export const UNSET_OPTION_VALUE = '__unset__'

export interface FieldDef<T> {
  key: keyof T
  label: string
  kind: FieldKind
  /** Required when kind === 'select'. Values can be numbers or strings -
   * onValueChange looks up the matching option and passes its original
   * `value` through unchanged, so the field's underlying type is preserved. */
  options?: { value: number | string; label: string }[]
}

export interface FieldGroupDef<T> {
  title: string
  fields: FieldDef<T>[]
}

interface FieldGroupFormProps<T> {
  groups: FieldGroupDef<T>[]
  draft: T
  updateField: (key: keyof T, value: unknown) => void
  editable: boolean
  disabledKeys?: (keyof T)[]
}

export function FieldGroupForm<T extends Record<string, any>>({
  groups, draft, updateField, editable, disabledKeys = [],
}: FieldGroupFormProps<T>) {
  return (
    <div className="space-y-4">
      {groups.map(group => (
        <div key={group.title} className="space-y-2">
          <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">{group.title}</p>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {group.fields.map(field => {
              const fieldId = String(field.key)
              const fieldDisabled = !editable || disabledKeys.includes(field.key)
              return (
                <div key={fieldId} className={field.kind === 'boolean' ? 'flex items-center gap-2' : 'space-y-1'}>
                  {field.kind === 'boolean' ? (
                    <>
                      <Checkbox
                        id={fieldId}
                        checked={Boolean(draft[field.key])}
                        onCheckedChange={v => updateField(field.key, v === true)}
                        disabled={fieldDisabled}
                      />
                      <Label htmlFor={fieldId}>{field.label}</Label>
                    </>
                  ) : field.kind === 'select' ? (
                    <>
                      <Label htmlFor={fieldId}>{field.label}</Label>
                      <Select
                        value={draft[field.key] == null ? UNSET_OPTION_VALUE : String(draft[field.key])}
                        onValueChange={v => {
                          if (v === UNSET_OPTION_VALUE) {
                            updateField(field.key, null)
                            return
                          }
                          const opt = field.options?.find(o => String(o.value) === v)
                          updateField(field.key, opt ? opt.value : v)
                        }}
                        disabled={fieldDisabled}
                      >
                        <SelectTrigger id={fieldId} className="w-full">
                          <SelectValue placeholder="—" />
                        </SelectTrigger>
                        <SelectContent>
                          {field.options?.map(opt => (
                            <SelectItem key={opt.value} value={String(opt.value)}>
                              {opt.label}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </>
                  ) : (
                    <>
                      <Label htmlFor={fieldId}>{field.label}</Label>
                      <Input
                        id={fieldId}
                        type={field.kind === 'number' ? 'number' : 'text'}
                        value={(draft[field.key] as string | number | null) ?? ''}
                        disabled={fieldDisabled}
                        onChange={e => {
                          const raw = e.target.value
                          if (field.kind === 'number') {
                            updateField(field.key, raw === '' ? null : Number(raw))
                          } else {
                            updateField(field.key, raw === '' ? null : raw)
                          }
                        }}
                      />
                    </>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      ))}
    </div>
  )
}
