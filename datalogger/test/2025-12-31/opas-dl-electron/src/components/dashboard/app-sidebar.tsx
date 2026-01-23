"use client"

import * as React from "react"
import {
    // AudioWaveform,
    BookOpen,
    Bot,
    // Command,
    Frame,
    Turtle,
    // GalleryVerticalEnd,
    Map,
    PieChart,
    Settings2,
    SquareTerminal,
} from "lucide-react"

import { NavMain } from "@/components/dashboard/nav-main"
import { NavProjects } from "@/components/dashboard/nav-projects"
import { NavUser } from "@/components/dashboard/nav-user"
import { NavCorp } from "@/components/dashboard/nav-corp"
import { Separator } from "@/components/ui/separator"
// import { TeamSwitcher } from "@/components/dashboard/team-switcher"
import {
    Sidebar,
    SidebarContent,
    SidebarFooter,
    SidebarHeader,
    SidebarRail,
    // SidebarTrigger
} from "@/components/ui/sidebar"

// This is sample data.
const data = {
    user: {
        name: "shadcn",
        email: "m@example.com",
        avatar: "/avatars/shadcn.jpg",
    },
    //   teams: [
    //     {
    //       name: "Acme Inc",
    //       logo: GalleryVerticalEnd,
    //       plan: "Enterprise",
    //     },
    //     {
    //       name: "Acme Corp.",
    //       logo: AudioWaveform,
    //       plan: "Startup",
    //     },
    //     {
    //       name: "Evil Corp.",
    //       logo: Command,
    //       plan: "Free",
    //     },
    //   ],
    corp: {
        name: "OPAS DL",
        logo: Turtle,
        plan: "Free",
    },
    // {
    //     name: "Evil Corp.",
    //     logo: Command,
    //     plan: "Free",
    // },
    navMain: [
        {
            title: "Playground",
            url: "#",
            icon: SquareTerminal,
            isActive: true,
            items: [
                {
                    title: "History",
                    url: "#",
                },
                {
                    title: "Starred",
                    url: "#",
                },
                {
                    title: "Settings",
                    url: "#",
                },
            ],
        },
        {
            title: "Models",
            url: "#",
            icon: Bot,
            items: [
                {
                    title: "Genesis",
                    url: "#",
                },
                {
                    title: "Explorer",
                    url: "#",
                },
                {
                    title: "Quantum",
                    url: "#",
                },
            ],
        },
        {
            title: "Documentation",
            url: "#",
            icon: BookOpen,
            items: [
                {
                    title: "Introduction",
                    url: "#",
                },
                {
                    title: "Get Started",
                    url: "#",
                },
                {
                    title: "Tutorials",
                    url: "#",
                },
                {
                    title: "Changelog",
                    url: "#",
                },
            ],
        },
        {
            title: "Settings",
            url: "#",
            icon: Settings2,
            items: [
                {
                    title: "General",
                    url: "#",
                },
                {
                    title: "Team",
                    url: "#",
                },
                {
                    title: "Billing",
                    url: "#",
                },
                {
                    title: "Limits",
                    url: "#",
                },
            ],
        },
    ],
    projects: [
        {
            name: "Design Engineering",
            url: "#",
            icon: Frame,
        },
        {
            name: "Sales & Marketing",
            url: "#",
            icon: PieChart,
        },
        {
            name: "Travel",
            url: "#",
            icon: Map,
        },
    ],
}

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
    return (
        <Sidebar collapsible="icon" {...props}>
            <SidebarHeader>
                {/* <TeamSwitcher teams={data.teams} /> */}
                <NavCorp corp={data.corp} />
            </SidebarHeader>
            <Separator
              orientation="horizontal"
              className="mr-2 data-[orientation=vertical]:h-4"
            />
            <SidebarContent>
                <NavMain items={data.navMain} />
                <NavProjects projects={data.projects} />
            </SidebarContent>
            <SidebarFooter>
                <NavUser user={data.user} />
            </SidebarFooter>
            <SidebarRail />
        </Sidebar>
    )
}
