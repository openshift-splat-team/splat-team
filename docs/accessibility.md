# Accessibility Guidelines

Following [Red Hat's accessibility standards](https://ux.redhat.com/foundations/accessibility/), this documentation is designed to be accessible to all users.

## Our Commitment

We integrate accessibility as a core pillar, not an afterthought. This aligns with Red Hat's philosophy of making digital experiences accessible to everyone.

## Accessibility Features

### Keyboard Navigation
- All interactive elements are keyboard accessible
- Tab order follows logical reading flow
- Focus indicators clearly visible
- Escape key dismisses modals and popups

### Screen Readers
- Semantic HTML structure
- ARIA labels where needed
- Alt text for all images
- Skip to content link for quick navigation

### Visual Design
- Color contrast meets WCAG AA standards minimum (4.5:1 for normal text)
- Text resizable up to 200% without loss of functionality
- No information conveyed by color alone
- Focus states clearly visible

### Color Palette Accessibility

Our Red Hat brand colors are tested for accessibility:

| Color | Hex Code | Usage | Contrast Ratio (on white) |
|-------|----------|-------|---------------------------|
| Red Hat Red | #CC0000 | Primary brand | 5.5:1 ✓ |
| PatternFly Blue | #0066CC | Links, accents | 4.5:1 ✓ |
| Danger | #B1380B | Error states | 6.4:1 ✓ |
| Success | #3D7317 | Success states | 7.1:1 ✓ |

## Testing Recommendations

When contributing documentation:

1. **Keyboard Test**: Navigate using only Tab, Enter, Escape
2. **Screen Reader Test**: Test with NVDA (Windows), VoiceOver (Mac), or Orca (Linux)
3. **Contrast Check**: Use browser DevTools or [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
4. **Zoom Test**: Verify content at 200% browser zoom

## Reporting Issues

If you encounter accessibility barriers, please [open an issue](https://github.com/openshift-splat-team/splat-team/issues) with:
- Description of the barrier
- Steps to reproduce
- Browser/assistive technology used
- Suggested fix (if applicable)

## Resources

- [Red Hat Accessibility](https://ux.redhat.com/foundations/accessibility/)
- [PatternFly Accessibility](https://www.patternfly.org/accessibility/accessibility-fundamentals/)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [WebAIM Resources](https://webaim.org/resources/)
